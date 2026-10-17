import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'secure_token_store.dart';
import 'session.dart';

/// Base URL from `--dart-define=API_BASE=...` (default https://api.tizbiz.uz).
final apiConfigProvider =
    Provider<ApiConfig>((ref) => ApiConfig.fromEnvironment(log: kDebugMode ? debugPrint : null));

/// Where the consumer JWT lives.
final tokenStoreProvider =
    Provider<TokenStore>((ref) => SecureTokenStore(const FlutterSecureStorage(), 'bizcat_consumer_token'));

/// The single HTTP client (consumer tokens only). A 401 on an authenticated request signs out.
final apiProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(apiConfigProvider),
    tokenKind: TokenKind.consumer,
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: (_) => ref.read(sessionProvider.notifier).handleUnauthorized(),
  );
  ref.onDispose(client.close);
  return client;
});
