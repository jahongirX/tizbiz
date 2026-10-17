import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// 2026-10-17 07:00Z = Saturday 17 Oct 2026, 12:00 Tashkent. Every test clock uses it.
final DateTime kTestNow = DateTime.utc(2026, 10, 17, 7);

/// What the client sent.
final class FakeRequest {
  FakeRequest({required this.method, required this.path, required this.query, required this.headers, required this.rawBody});

  final String method;

  /// Path without query, e.g. '/v1/appointments'.
  final String path;
  final Map<String, String> query;

  /// Lower-cased names.
  final Map<String, String> headers;
  final String rawBody;

  /// Body decoded as JSON (null when empty / not JSON).
  Object? get body {
    if (rawBody.isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => '$method $path${query.isEmpty ? '' : '?$query'}';
}

final class _Reply {
  _Reply({required this.status, this.body, this.headers = const {}, this.error});

  final int status;
  final Object? body;
  final Map<String, String> headers;
  final DioExceptionType? error;
}

/// dio [HttpClientAdapter] answering registered routes; unmatched requests get 404.
///
/// `on('GET', '/v1/auth/me', body: {'data': {...}})` - body is JSON-encoded unless it is a String.
/// Several registrations of the same route are served in order (one per request); the last one
/// repeats. A registration added later is served once the earlier ones were used.
final class FakeHttp implements HttpClientAdapter {
  final Map<String, List<_Reply>> _routes = {};
  final Map<String, int> _served = {};

  /// Every request, in order.
  final List<FakeRequest> requests = [];

  /// When true every request fails with a connection error (ApiException.isNetwork).
  bool offline = false;

  static String _key(String method, String path) => '${method.toUpperCase()} $path';

  void on(String method, String path, {int status = 200, Object? body, Map<String, String> headers = const {}}) {
    _routes.putIfAbsent(_key(method, path), () => []).add(_Reply(status: status, body: body, headers: headers));
  }

  /// The route fails at the transport level (default: no connection).
  void onNetworkError(String method, String path, {DioExceptionType type = DioExceptionType.connectionError}) {
    _routes.putIfAbsent(_key(method, path), () => []).add(_Reply(status: 0, error: type));
  }

  /// Requests to [path] (any method when [method] is null).
  List<FakeRequest> calls(String path, {String? method}) => [
        for (final r in requests)
          if (r.path == path && (method == null || r.method == method.toUpperCase())) r,
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final uri = options.uri;
    requests.add(FakeRequest(
      method: options.method.toUpperCase(),
      path: uri.path,
      query: uri.queryParameters,
      headers: {for (final e in options.headers.entries) e.key.toLowerCase(): '${e.value}'},
      rawBody: utf8.decode(bytes, allowMalformed: true),
    ));
    if (offline) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: 'offline');
    }
    final key = _key(options.method, uri.path);
    final list = _routes[key];
    if (list == null || list.isEmpty) {
      return _body(404, {
        'errors': [
          {'status': '404', 'title': 'Not Found', 'detail': 'FakeHttp: no route for ${options.method} ${uri.path}'},
        ],
      }, const {});
    }
    final n = _served[key] ?? 0;
    _served[key] = n + 1;
    final reply = list[n < list.length ? n : list.length - 1];
    final error = reply.error;
    if (error != null) throw DioException(requestOptions: options, type: error, error: 'fake $error');
    return _body(reply.status, reply.body, reply.headers);
  }

  ResponseBody _body(int status, Object? body, Map<String, String> headers) => ResponseBody.fromString(
        body == null ? '' : (body is String ? body : jsonEncode(body)),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=UTF-8'],
          for (final e in headers.entries) e.key: [e.value],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Unsigned JWT (dummy header + signature) with a base64url JSON payload.
String fakeJwt(Map<String, Object?> payload) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'typ': 'JWT', 'alg': 'HS256'})}.${seg(payload)}.c2lnbmF0dXJl';
}

/// A business ('biz') token; expires a week after [kTestNow] unless [exp] is given.
String fakeBizToken({int sub = 4, int? tid = 2, String role = 'business_owner', DateTime? exp}) => fakeJwt({
      'iss': 'tizbiz.uz',
      'sub': sub,
      'tid': ?tid,
      'role': role,
      'typ': 'biz',
      'exp': Dates.toUnix(exp ?? kTestNow.add(const Duration(days: 7))),
    });

/// An [ApiClient] on [http] (base 'https://api.test', clock pinned to [kTestNow]).
/// [token] is preloaded into an in-memory store (or pass your own [store]).
ApiClient fakeApi(
  FakeHttp http, {
  String? token,
  TokenStore? store,
  UnauthorizedHandler? onUnauthorized,
  DateTime Function()? clock,
}) {
  final dio = Dio()..httpClientAdapter = http;
  return ApiClient(
    config: const ApiConfig(baseUrl: 'https://api.test'),
    tokenKind: TokenKind.biz,
    tokenStore: store ?? InMemoryTokenStore(token),
    onUnauthorized: onUnauthorized,
    dio: dio,
    clock: clock ?? () => kTestNow,
  );
}

/// `{"data": data}` envelope.
Map<String, Object?> envelope(Object? data, {Map<String, Object?>? meta}) => {'data': data, 'meta': ?meta};

/// `{"errors":[{status,title,detail,source?}]}`.
Map<String, Object?> apiError(int status, String detail, {String title = 'Error', String? pointer}) => {
      'errors': [
        {
          'status': '$status',
          'title': title,
          'detail': detail,
          if (pointer != null) 'source': {'pointer': pointer},
        },
      ],
    };
