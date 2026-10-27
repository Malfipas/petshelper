/// API key 的安全存储。
///
/// key 不进数据库、不打日志，读写都走系统凭据：Windows 是凭据管理器，macOS 是
/// Keychain。设置页写与清，B22 的 AI 客户端读；测试注入假实现，不碰真实凭据。
abstract interface class SecureKeyGateway {
  /// 读出已存的 key；没有或读不出来都返回 null。
  Future<String?> read();

  /// 存下 key，覆盖旧的。
  Future<void> write(String key);

  /// 抹掉 key，之后 `read` 返回 null。
  Future<void> clear();
}
