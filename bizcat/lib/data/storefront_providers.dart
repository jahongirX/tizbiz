import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../core/api.dart';

/// GET /v1/site/{slug} (no token) -> engine, business, services, staff, categories, items.
/// Kept alive after success so the detail page, flows, cart and checkout share one fetch;
/// pull-to-refresh calls `ref.invalidate(storefrontProvider(slug))`.
final storefrontProvider = FutureProvider.autoDispose.family<StorefrontData, String>((ref, slug) async {
  final data = await ref.read(apiProvider).get<StorefrontData>(
        Endpoints.site(slug),
        auth: RequestAuth.none,
        decode: (d) => StorefrontData.fromJson(JsonRead.object(d)),
      );
  if (ref.mounted) ref.keepAlive();
  return data;
});
