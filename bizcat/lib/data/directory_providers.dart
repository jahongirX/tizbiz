import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../core/api.dart';
import '../core/revisions.dart';
import '../core/session.dart';
import 'directory_query.dart';

/// GET /v1/directory/categories (public). Kept alive for the app's lifetime.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.read(apiProvider).getList(Endpoints.directoryCategories, Category.fromJson, auth: RequestAuth.none);
});

/// `GET /v1/directory/businesses?<query>` (a consumer token fills is_favorite).
final businessListProvider = FutureProvider.autoDispose.family<Paged<BusinessCard>, DirectoryQuery>((ref, query) {
  ref.watch(consumerIdProvider);
  return ref.read(apiProvider).getPage(Endpoints.directoryBusinesses, BusinessCard.fromJson, query: query.toQuery());
});

/// GET /v1/directory/businesses/{slug}. Re-read after sign-in/out and after reviews change.
/// 404 -> ApiException.isNotFound.
final businessPageProvider = FutureProvider.autoDispose.family<BusinessPage, String>((ref, slug) {
  ref
    ..watch(consumerIdProvider)
    ..watch(reviewsRevisionProvider);
  return ref
      .read(apiProvider)
      .get<BusinessPage>(Endpoints.directoryBusiness(slug), decode: (d) => BusinessPage.fromJson(JsonRead.object(d)));
});
