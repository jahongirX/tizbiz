import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../core/api.dart';
import '../../core/session.dart';

const Object _keep = Object();

/// Query of GET /v1/directory/map (a family key: has ==/hashCode).
@immutable
final class MapQuery {
  const MapQuery({this.q, this.category, this.bbox, this.minRating});

  final String? q, category;

  /// e.g. 4.5 = only businesses rated 4.5 and up.
  final double? minRating;

  /// 'minLng,minLat,maxLng,maxLat' of a "search this area" viewport; null = everywhere.
  final String? bbox;

  Map<String, Object?> toQuery() {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return {'q': ?clean(q), 'category': ?clean(category), 'bbox': ?clean(bbox), 'min_rating': ?minRating?.toString()};
  }

  /// Nullable fields use a sentinel: `copyWith(bbox: null)` clears it.
  MapQuery copyWith({Object? q = _keep, Object? category = _keep, Object? bbox = _keep, Object? minRating = _keep}) =>
      MapQuery(
        q: identical(q, _keep) ? this.q : q as String?,
        category: identical(category, _keep) ? this.category : category as String?,
        bbox: identical(bbox, _keep) ? this.bbox : bbox as String?,
        minRating: identical(minRating, _keep) ? this.minRating : minRating as double?,
      );

  @override
  bool operator ==(Object other) =>
      other is MapQuery &&
      other.q == q &&
      other.category == category &&
      other.bbox == bbox &&
      other.minRating == minRating;

  @override
  int get hashCode => Object.hash(q, category, bbox, minRating);
}

/// The viewport as a bbox param, rounded so tiny pans reuse the cached result.
String bboxParam({required double west, required double south, required double east, required double north}) {
  String f(double v) => v.toStringAsFixed(4);
  return '${f(west)},${f(south)},${f(east)},${f(north)}';
}

/// `GET /v1/directory/map?<query>`: businesses with coordinates (best rated first, at most 300).
final mapResultsProvider = FutureProvider.autoDispose.family<List<BusinessCard>, MapQuery>((ref, query) {
  ref.watch(consumerIdProvider);
  return ref.read(apiProvider).getList(Endpoints.directoryMap, BusinessCard.fromJson, query: query.toQuery());
});
