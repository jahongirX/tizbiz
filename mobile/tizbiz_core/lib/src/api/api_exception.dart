import 'package:meta/meta.dart';

import '../util/json_read.dart';

enum ApiErrorKind { http, network, timeout, cancelled, decode }

/// One item of the error envelope `{"errors":[...]}` (RFC-7807 style).
@immutable
final class ApiErrorItem {
  const ApiErrorItem({required this.status, required this.title, required this.detail, this.code, this.pointer});

  /// Keys: status (string|int), title, detail, code?, source.pointer?.
  factory ApiErrorItem.fromJson(Map<String, dynamic> json) => ApiErrorItem(
        status: JsonRead.integer(json['status']),
        title: JsonRead.string(json['title']),
        detail: JsonRead.string(json['detail']),
        code: JsonRead.nonEmptyOrNull(json['code']),
        pointer: JsonRead.nonEmptyOrNull(JsonRead.objectOrNull(json['source'])?['pointer']),
      );

  final int status;
  final String title;
  final String detail;
  final String? code;

  /// json: source.pointer, e.g. 'phone', 'items[2].end_time'.
  final String? pointer;

  Map<String, dynamic> toJson() => {
        'status': status.toString(),
        'title': title,
        'detail': detail,
        if (code != null) 'code': code,
        if (pointer != null) 'source': {'pointer': pointer},
      };
}

/// Every failure of [ApiClient] calls: HTTP errors, transport errors and undecodable bodies.
final class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.status,
    this.title = '',
    this.detail = '',
    this.code,
    this.fieldErrors = const {},
    this.errors = const [],
    this.retryAfter,
    this.cause,
  });

  /// Parses `{"errors":[...]}`. status = int.tryParse(errors[0].status) ?? httpStatus.
  /// fieldErrors = { pointer: detail } for every item that has source.pointer (first wins per
  /// pointer). title/detail/code from errors[0]. retryAfter from header 'retry-after' (seconds).
  /// Non-JSON or envelope-less body -> kind http, title '', detail ''.
  factory ApiException.fromResponse(int httpStatus, Object? body, Map<String, List<String>> headers) {
    Duration? retryAfter;
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == 'retry-after' && e.value.isNotEmpty) {
        final secs = int.tryParse(e.value.first.trim());
        if (secs != null && secs >= 0) retryAfter = Duration(seconds: secs);
      }
    }
    final rawItems = body is Map ? body['errors'] : null;
    if (rawItems is! List || rawItems.isEmpty) {
      return ApiException(kind: ApiErrorKind.http, status: httpStatus, retryAfter: retryAfter);
    }
    final items = JsonRead.list(rawItems, ApiErrorItem.fromJson);
    if (items.isEmpty) {
      return ApiException(kind: ApiErrorKind.http, status: httpStatus, retryAfter: retryAfter);
    }
    final firstRaw = JsonRead.objectOrNull(rawItems.first);
    final status = JsonRead.integerOrNull(firstRaw?['status']) ?? httpStatus;
    final fieldErrors = <String, String>{};
    for (final item in items) {
      final p = item.pointer;
      if (p != null) fieldErrors.putIfAbsent(p, () => item.detail);
    }
    final first = items.first;
    return ApiException(
      kind: ApiErrorKind.http,
      status: status,
      title: first.title,
      detail: first.detail,
      code: first.code,
      fieldErrors: Map.unmodifiable(fieldErrors),
      errors: List.unmodifiable(items),
      retryAfter: retryAfter,
    );
  }

  /// Transport error (status 0).
  factory ApiException.network(ApiErrorKind kind, {Object? cause}) =>
      ApiException(kind: kind, status: 0, cause: cause);

  final ApiErrorKind kind;

  /// HTTP status; 0 for transport errors.
  final int status;

  /// e.g. 'Conflict', 'Validation error'.
  final String title;

  /// Server text, usually Uzbek.
  final String detail;
  final String? code;

  /// 422 with pointer only.
  final Map<String, String> fieldErrors;
  final List<ApiErrorItem> errors;

  /// 429 resend.
  final Duration? retryAfter;
  final Object? cause;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;

  /// Both 422 shapes (with and without pointer).
  bool get isValidation => status == 422;
  bool get isRateLimited => status == 429;
  bool get isServer => status >= 500;
  bool get isNetwork => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;
  bool get isCancelled => kind == ApiErrorKind.cancelled;
  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  String? fieldError(String pointer) => fieldErrors[pointer];

  static const Map<String, String> _translations = {
    'Your request was made with invalid credentials.': 'Sessiya tugadi. Qaytadan kiring.',
    'No active business selected.': 'Faol biznes tanlanmagan.',
    'Insufficient role for this action.': "Bu amal uchun ruxsatingiz yo'q.",
    'Login required': 'Tizimga kiring.',
  };

  /// User-facing Uzbek text. Never empty.
  String get message {
    switch (kind) {
      case ApiErrorKind.network:
        return "Internet aloqasi yo'q. Qayta urinib ko'ring.";
      case ApiErrorKind.timeout:
        return "Server javob bermadi. Qayta urinib ko'ring.";
      case ApiErrorKind.cancelled:
        return "So'rov bekor qilindi.";
      case ApiErrorKind.decode:
        return "Serverdan noto'g'ri javob keldi.";
      case ApiErrorKind.http:
        break;
    }
    final d = detail.trim();
    final translated = _translations[d];
    if (translated != null) return translated;
    if (d.isNotEmpty) return detail;
    for (final v in fieldErrors.values) {
      if (v.trim().isNotEmpty) return v;
    }
    return switch (status) {
      400 => "So'rov noto'g'ri.",
      401 => 'Sessiya tugadi. Qaytadan kiring.',
      403 => "Bu amal uchun ruxsatingiz yo'q.",
      404 => 'Topilmadi.',
      409 => "Amalni bajarib bo'lmadi: ma'lumot o'zgargan.",
      422 => "Ma'lumotlar noto'g'ri to'ldirilgan.",
      429 => "Juda ko'p urinish. Keyinroq urinib ko'ring.",
      >= 500 => "Serverda xatolik. Keyinroq urinib ko'ring.",
      _ => 'Xatolik yuz berdi.',
    };
  }

  /// 'ApiException(409 Conflict: Tanlangan vaqt band.)'.
  @override
  String toString() {
    final label = title.isNotEmpty ? title : kind.name;
    return 'ApiException($status $label: $message)';
  }
}
