import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tizbiz_biznes/core/secure_token_store.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Where the business JWT lives (key `tizbiz_biz_token`).
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore(const FlutterSecureStorage()));

/// The app's single HTTP client. A 401 on an authenticated request logs the session out.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ApiConfig.fromEnvironment(log: kDebugMode ? debugPrint : null),
    tokenKind: TokenKind.biz,
    tokenStore: ref.watch(tokenStoreProvider),
    // Read lazily: the session notifier itself reads this provider (no build cycle).
    onUnauthorized: (e) => ref.read(sessionProvider.notifier).onUnauthorized(e),
  );
  ref.onDispose(client.close);
  return client;
});
