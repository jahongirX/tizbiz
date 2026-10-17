import 'package:meta/meta.dart';

import '../util/json_read.dart';

/// A decoded 2xx response: the unwrapped envelope `data`, plus `meta` and headers.
@immutable
final class ApiResponse<T> {
  const ApiResponse({required this.statusCode, required this.data, this.meta, this.headers = const {}});

  final int statusCode;

  /// Unwrapped `data` (null for 204).
  final T data;

  /// Present when the envelope has `meta`.
  final PageMeta? meta;

  /// Lower-cased names.
  final Map<String, List<String>> headers;

  /// true for 200 on a create endpoint that answers 201 for a new row (idempotent replay).
  bool get isReplay => statusCode == 200;
  bool get isCreated => statusCode == 201;
}

/// Pagination envelope `meta` {page, per_page, total, pages, ...extra}.
@immutable
final class PageMeta {
  const PageMeta({
    required this.page,
    required this.perPage,
    required this.total,
    required this.pages,
    this.extra = const {},
  });

  /// Synthesised for a non-paginated list: page 1 of 1.
  factory PageMeta.single(int count) => PageMeta(page: 1, perPage: count, total: count, pages: 1);

  /// Keys: page, per_page, total, pages; every other key -> extra.
  factory PageMeta.fromJson(Map<String, dynamic> json) {
    const standard = {'page', 'per_page', 'total', 'pages'};
    final total = JsonRead.integer(json['total']);
    final perPage = JsonRead.integer(json['per_page'], 20);
    return PageMeta(
      page: JsonRead.integer(json['page'], 1),
      perPage: perPage,
      total: total,
      pages: JsonRead.integerOrNull(json['pages']) ??
          (total == 0 || perPage <= 0 ? 0 : (total + perPage - 1) ~/ perPage),
      extra: {
        for (final e in json.entries)
          if (!standard.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// json: page.
  final int page;

  /// json: per_page.
  final int perPage;

  /// json: total.
  final int total;

  /// json: pages (0 when total == 0).
  final int pages;

  /// Non-standard meta keys, e.g. reviews: avg, count, distribution.
  final Map<String, dynamic> extra;

  bool get hasMore => page < pages;
  int? get nextPage => hasMore ? page + 1 : null;

  Map<String, dynamic> toJson() => {
        'page': page,
        'per_page': perPage,
        'total': total,
        'pages': pages,
        ...extra,
      };

  @override
  bool operator ==(Object other) =>
      other is PageMeta &&
      other.page == page &&
      other.perPage == perPage &&
      other.total == total &&
      other.pages == pages;

  @override
  int get hashCode => Object.hash(page, perPage, total, pages);

  @override
  String toString() => 'PageMeta(page: $page/$pages, perPage: $perPage, total: $total)';
}

/// One page of a list plus its [PageMeta].
@immutable
final class Paged<T> {
  const Paged({required this.items, required this.meta});

  final List<T> items;
  final PageMeta meta;

  bool get hasMore => meta.hasMore;
  bool get isEmpty => items.isEmpty;

  /// Appends the next page (for infinite scroll); keeps `next.meta`.
  Paged<T> append(Paged<T> next) => Paged<T>(items: [...items, ...next.items], meta: next.meta);

  Paged<R> map<R>(R Function(T) f) => Paged<R>(items: items.map(f).toList(), meta: meta);
}
