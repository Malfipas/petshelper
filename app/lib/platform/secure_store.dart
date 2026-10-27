import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

import '../domain/port/secure_key_gateway.dart';

/// 走系统凭据的 key 存储。
///
/// Windows 上先用 DPAPI（`CryptProtectData`）把 key 加密成一段只有当前用户、
/// 当前机器能解开的字节，再落盘成 `api_key.bin`。文件被拷走、被别的账户读到都
/// 解不出明文；换机器或重装系统则解不开，`read` 会当作没存过。
///
/// 没有用现成的 secure storage 插件：Windows 那个实现要编译器带 ATL，本机没有，
/// 构建直接过不去。DPAPI 是系统自带的，不用额外组件。
///
/// macOS 的 Keychain 与 Linux 的 libsecret 留到真要上那两个平台时补；在那之前
/// 写会明确失败（设置页显示「保存失败」），不做「悄悄存明文」这种降级。
class SystemSecureKeyGateway implements SecureKeyGateway {
  SystemSecureKeyGateway({Future<File> Function()? keyFile})
    : _keyFile = keyFile ?? _defaultKeyFile;

  /// 存放密文的文件。测试可换成临时目录。
  final Future<File> Function() _keyFile;

  /// 密文文件名。改它等于让所有人都要重填一次 key，不要动。
  static const String fileName = 'api_key.bin';

  static Future<File> _defaultKeyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }

  @override
  Future<String?> read() async {
    if (!Platform.isWindows) return null;
    final file = await _keyFile();
    if (!await file.exists()) return null;

    try {
      final text = utf8.decode(_unprotect(await file.readAsBytes())).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      // 换了机器、换了账户、文件被改坏：一律当没存过，别把坏数据交给 AI 客户端。
      return null;
    }
  }

  @override
  Future<void> write(String key) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('目前只有 Windows 实现了 key 的安全存储');
    }
    final file = await _keyFile();
    await file.parent.create(recursive: true);
    await file.writeAsBytes(_protect(utf8.encode(key)), flush: true);
  }

  @override
  Future<void> clear() async {
    final file = await _keyFile();
    if (await file.exists()) await file.delete();
  }
}

/// 加密成一段只有当前用户能解开的字节。
Uint8List _protect(List<int> plain) {
  final input = calloc<Uint8>(plain.length);
  final inBlob = calloc<CRYPT_INTEGER_BLOB>();
  final outBlob = calloc<CRYPT_INTEGER_BLOB>();

  try {
    input.asTypedList(plain.length).setAll(0, plain);
    inBlob.ref
      ..cbData = plain.length
      ..pbData = input;

    final ok = CryptProtectData(
      inBlob,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      0,
      outBlob,
    );
    if (ok == 0) {
      throw StateError('DPAPI 加密失败，错误码 ${GetLastError()}');
    }
    return Uint8List.fromList(
      outBlob.ref.pbData.asTypedList(outBlob.ref.cbData),
    );
  } finally {
    if (outBlob.ref.pbData != nullptr) LocalFree(outBlob.ref.pbData.cast());
    free(outBlob);
    free(inBlob);
    free(input);
  }
}

/// 把 `_protect` 出来的字节解回明文。换过机器或账户会抛错。
Uint8List _unprotect(List<int> sealed) {
  final input = calloc<Uint8>(sealed.length);
  final inBlob = calloc<CRYPT_INTEGER_BLOB>();
  final outBlob = calloc<CRYPT_INTEGER_BLOB>();

  try {
    input.asTypedList(sealed.length).setAll(0, sealed);
    inBlob.ref
      ..cbData = sealed.length
      ..pbData = input;

    final ok = CryptUnprotectData(
      inBlob,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      0,
      outBlob,
    );
    if (ok == 0) {
      throw StateError('DPAPI 解密失败，错误码 ${GetLastError()}');
    }
    return Uint8List.fromList(
      outBlob.ref.pbData.asTypedList(outBlob.ref.cbData),
    );
  } finally {
    if (outBlob.ref.pbData != nullptr) LocalFree(outBlob.ref.pbData.cast());
    free(outBlob);
    free(inBlob);
    free(input);
  }
}
