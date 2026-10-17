import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// What the app sent.
final class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.rawBody,
  });

  /// Upper case ('GET').
  final String method;

  /// Without the query ('/v1/consumer/me').
  final String path;
  final Map<String, String> query;

  /// Lower-cased names.
  final Map<String, String> headers;

  /// '' when there was no body.
  final String rawBody;

  /// The body decoded as JSON (null when empty or not JSON).
  Object? get body {
    if (rawBody.isEmpty) return null;
    try {
      return jsonDecode(rawBody);
    } on FormatException {
      return null;
    }
  }

  /// [body] as a map (empty when not a JSON object).
  Map<String, dynamic> get json {
    final b = body;
    return b is Map<String, dynamic> ? b : const {};
  }

  bool get hasAuth => headers.containsKey('authorization');

  @override
  String toString() => '$method $path${query.isEmpty ? '' : '?$query'} ${rawBody.isEmpty ? '' : rawBody}';
}

final class _Stub {
  _Stub(this.method, this.path, this.status, this.body, this.headers, this.when, this.networkError, this.times);

  final String method;
  final String path;
  final int status;
  final Object? body;
  final Map<String, String> headers;
  final bool Function(Map<String, String> query)? when;
  final bool networkError;
  int? times;
}

/// A scripted HTTP backend for widget tests (no network).
///
/// `api.on('GET', '/v1/consumer/me', body: Fx.me)`. The LAST matching registration wins, so a
/// test can override a default from `pumpBizcat`. Unmatched requests answer 404
/// `{"errors":[{"status":"404","title":"Not Found","detail":"Topilmadi."}]}` and are recorded.
final class FakeApi {
  FakeApi();

  final List<_Stub> _stubs = [];
  final List<RecordedRequest> requests = [];

  /// The token store of the last [client] (assert it was cleared after a 401).
  InMemoryTokenStore? tokenStore;

  late final _FakeAdapter _adapter = _FakeAdapter(this);

  /// Registers a response. [path] is matched exactly (no query); [when] filters on the query.
  /// [networkError] simulates no connection (ApiException.isNetwork). [times] limits how often the
  /// stub answers (null = always).
  void on(
    String method,
    String path, {
    int status = 200,
    Object? body,
    Map<String, String> headers = const {},
    bool Function(Map<String, String> query)? when,
    bool networkError = false,
    int? times,
  }) {
    _stubs.add(_Stub(method.toUpperCase(), path, status, body, headers, when, networkError, times));
  }

  /// Removes every registration for [method] + [path].
  void off(String method, String path) =>
      _stubs.removeWhere((s) => s.method == method.toUpperCase() && s.path == path);

  /// Every recorded request for [method] + [path], oldest first.
  List<RecordedRequest> all(String method, String path) =>
      [for (final r in requests) if (r.method == method.toUpperCase() && r.path == path) r];

  /// The latest request for [method] + [path]; throws a [StateError] when there is none.
  RecordedRequest last(String method, String path) {
    final list = all(method, path);
    if (list.isEmpty) {
      throw StateError('No $method $path recorded. Requests: ${requests.join('\n')}');
    }
    return list.last;
  }

  /// Whether [method] + [path] was requested.
  bool called(String method, String path) => all(method, path).isNotEmpty;

  void clearRequests() => requests.clear();

  /// An ApiClient for consumer tokens on 'https://api.test' wired to this fake.
  ApiClient client({String? token, UnauthorizedHandler? onUnauthorized}) {
    final store = InMemoryTokenStore(token);
    tokenStore = store;
    return ApiClient(
      config: const ApiConfig(baseUrl: 'https://api.test'),
      tokenKind: TokenKind.consumer,
      tokenStore: store,
      onUnauthorized: onUnauthorized,
      dio: Dio()..httpClientAdapter = _adapter,
    );
  }

  _Stub? _match(RecordedRequest r) {
    for (final s in _stubs.reversed) {
      if (s.method != r.method || s.path != r.path) continue;
      if (s.when != null && !s.when!(r.query)) continue;
      if (s.times != null && s.times! <= 0) continue;
      if (s.times != null) s.times = s.times! - 1;
      return s;
    }
    return null;
  }
}

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._api);

  final FakeApi _api;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final uri = options.uri;
    final rec = RecordedRequest(
      method: options.method.toUpperCase(),
      path: uri.path,
      query: Map.unmodifiable(uri.queryParameters),
      headers: {for (final e in options.headers.entries) e.key.toLowerCase(): '${e.value}'},
      rawBody: utf8.decode(bytes, allowMalformed: true),
    );
    _api.requests.add(rec);
    final stub = _api._match(rec);
    if (stub == null) {
      return _json(404, {
        'errors': [
          {'status': '404', 'title': 'Not Found', 'detail': 'Topilmadi.'},
        ],
      });
    }
    if (stub.networkError) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError, error: 'fake offline');
    }
    return _json(stub.status, stub.body, stub.headers);
  }

  ResponseBody _json(int status, Object? body, [Map<String, String> headers = const {}]) {
    final text = body == null ? '' : (body is String ? body : jsonEncode(body));
    return ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=UTF-8'],
        for (final e in headers.entries) e.key.toLowerCase(): [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An unsigned JWT with typ 'consumer' (the client only decodes it).
String fakeConsumerToken({int sub = 17, Duration ttl = const Duration(days: 30)}) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final now = DateTime.now().toUtc();
  final payload = {
    'iss': 'tizbiz.uz',
    'sub': sub,
    'typ': 'consumer',
    'iat': Dates.toUnix(now),
    'exp': Dates.toUnix(now.add(ttl)),
  };
  return '${seg({'typ': 'JWT', 'alg': 'HS256'})}.${seg(payload)}.c2lnbmF0dXJl';
}
