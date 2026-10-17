/// Persistent storage for the app's single JWT. Apps implement it with flutter_secure_storage.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// In-memory [TokenStore] (default for [ApiClient] and for tests).
final class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([String? initial]) : _token = initial;

  String? _token;

  /// Current value without a Future (tests).
  String? get value => _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
