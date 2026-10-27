import '../../domain/model/settings.dart';
import '../dao/settings_dao.dart';
import '../db/app_db.dart' as db;
import '../mapping/row_mappers.dart';

/// 设置的取数入口。
///
/// 管一张表：settings。整表只有一行，没有就按默认值建出来。
/// API key 本身不在这张表里，这里只记配没配——key 的读写在 B21 的 SecureKeyStore，
/// 两处配合：存了 key 就把这行置真。
class SettingsRepository {
  SettingsRepository(db.AppDb database) : _settings = SettingsDao(database);

  /// 演示视频地址的占位值，库里空着时显示它。真实链接定了再换。
  static const String demoUrlPlaceholder = 'https://example.com/ai-pet-demo.mp4';

  /// 项目仓库地址的占位值，库里空着时显示它。
  ///
  /// 这一版只读展示、可一键复制：仓库已经建好，就不再挂 example.com 那种
  /// 复制走也打不开的假地址。
  static const String repoUrlPlaceholder = 'https://github.com/Malfipas/petshelper';

  final SettingsDao _settings;

  Stream<Settings?> watch() => _settings.watchCurrent().map((row) => row?.toDomain());

  Future<Settings> current() async => (await _settings.ensureRow()).toDomain();

  Future<void> setKeyConfigured(bool value) => _edit((row) => row.copyWith(keyConfigured: value));

  Future<void> setDemoUrl(String url) => _edit((row) => row.copyWith(demoUrl: url));

  Future<void> setRepoUrl(String url) => _edit((row) => row.copyWith(repoUrl: url));

  Future<void> setBubbleEnabled(bool value) => _edit((row) => row.copyWith(bubbleEnabled: value));

  Future<void> setSide(PetSide side) => _edit((row) => row.copyWith(side: side.dbValue));

  Future<void> setAnchorY(double y) => _edit((row) => row.copyWith(anchorY: y));

  Future<void> _edit(db.Setting Function(db.Setting row) change) async {
    final row = await _settings.ensureRow();
    await _settings.updateRow(change(row));
  }
}
