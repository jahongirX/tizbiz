import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// [TokenStore] backed by flutter_secure_storage (Keychain / Keystore; WebCrypto + localStorage on
/// web). Storage failures never crash the app: a failed read is treated as "no token".
final class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage, [this._key = 'tizbiz_biz_token']);

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } on Object catch (e) {
      debugPrint('SecureTokenStore.read failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } on Object catch (e) {
      debugPrint('SecureTokenStore.write failed: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (e) {
      debugPrint('SecureTokenStore.clear failed: $e');
    }
  }
}
