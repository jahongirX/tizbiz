import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// [TokenStore] on flutter_secure_storage (CORE §4.1).
final class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage, this._key);

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
