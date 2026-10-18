import 'package:flutter/foundation.dart';

const Object _keep = Object();

/// Query of GET /v1/directory/businesses (a family key: has ==/hashCode).
@immutable
final class DirectoryQuery {
  const DirectoryQuery({
    this.q,
    this.category,
    this.engine,
    this.city,
    this.sort = 'featured',
    this.page = 1,
    this.perPage = 20,
  });

  final String? q, category, engine, city;

  /// featured | rating | new | name (BP 4.4).
  final String sort;
  final int page, perPage;

  static const List<String> sorts = ['featured', 'rating', 'new', 'name'];

  /// {'q','category','engine','city','sort','page','per_page'}; null/blank values dropped, q trimmed.
  Map<String, Object?> toQuery() {
    String? clean(String? v) {
      final t = v?.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return {
      'q': ?clean(q),
      'category': ?clean(category),
      'engine': ?clean(engine),
      'city': ?clean(city),
      'sort': ?clean(sort),
      'page': page,
      'per_page': perPage,
    };
  }

  /// Nullable fields use a sentinel: `copyWith(category: null)` clears it.
  DirectoryQuery copyWith({
    Object? q = _keep,
    Object? category = _keep,
    Object? engine = _keep,
    Object? city = _keep,
    String? sort,
    int? page,
    int? perPage,
  }) => DirectoryQuery(
    q: identical(q, _keep) ? this.q : q as String?,
    category: identical(category, _keep) ? this.category : category as String?,
    engine: identical(engine, _keep) ? this.engine : engine as String?,
    city: identical(city, _keep) ? this.city : city as String?,
    sort: sort ?? this.sort,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  @override
  bool operator ==(Object other) =>
      other is DirectoryQuery &&
      other.q == q &&
      other.category == category &&
      other.engine == engine &&
      other.city == city &&
      other.sort == sort &&
      other.page == page &&
      other.perPage == perPage;

  @override
  int get hashCode => Object.hash(q, category, engine, city, sort, page, perPage);

  @override
  String toString() => 'DirectoryQuery(${toQuery()})';
}
