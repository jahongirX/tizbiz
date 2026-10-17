import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One queued reply: either an HTTP response or a transport error.
final class FakeReply {
  FakeReply(this.status, this.body, [this.headers = const {}]) : error = null;
  FakeReply.error(DioExceptionType this.error)
      : status = 0,
        body = '',
        headers = const {};

  final int status;
  final String body;
  final Map<String, List<String>> headers;
  final DioExceptionType? error;
}

/// What the client actually sent.
final class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;

  /// Lower-cased header names.
  final Map<String, String> headers;

  /// Raw body text ('' when none).
  final String body;

  /// Body decoded as JSON (null when empty or not JSON).
  Object? get json {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

/// [HttpClientAdapter] that answers from a queue and records every request.
final class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([List<FakeReply>? replies]) {
    if (replies != null) queue.addAll(replies);
  }

  final List<FakeReply> queue = [];
  final List<RecordedRequest> requests = [];

  /// Delay before answering (lets concurrent requests overlap).
  Duration delay = Duration.zero;

  void reply(int status, String body, [Map<String, List<String>> headers = const {}]) =>
      queue.add(FakeReply(status, body, headers));

  void fail(DioExceptionType type) => queue.add(FakeReply.error(type));

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
    requests.add(RecordedRequest(
      options.method,
      options.uri,
      {for (final e in options.headers.entries) e.key.toLowerCase(): '${e.value}'},
      utf8.decode(bytes, allowMalformed: true),
    ));
    await Future<void>.delayed(delay);
    if (queue.isEmpty) {
      throw StateError('FakeAdapter: no reply queued for ${options.method} ${options.uri}');
    }
    final next = queue.removeAt(0);
    final error = next.error;
    if (error != null) {
      throw DioException(requestOptions: options, type: error, error: 'fake $error');
    }
    return ResponseBody.fromString(
      next.body,
      next.status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=UTF-8'],
        ...next.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Builds an unsigned JWT with [payload] (dummy header and signature, no base64 padding).
String makeToken(Map<String, Object?> payload) {
  String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'typ': 'JWT', 'alg': 'HS256'})}.${seg(payload)}.c2lnbmF0dXJl';
}

/// 2026-10-17 07:00Z: before every test token's exp.
final DateTime testNow = DateTime.utc(2026, 10, 17, 7);

/// exp one week after [testNow].
final int testExp = Dates.toUnix(DateTime.utc(2026, 10, 24, 7));

String bizToken({int sub = 4, int? exp}) =>
    makeToken({'iss': 'tizbiz.uz', 'sub': sub, 'tid': 2, 'role': 'business_owner', 'typ': 'biz', 'exp': exp ?? testExp});

String consumerToken({int sub = 17, int? exp}) =>
    makeToken({'iss': 'tizbiz.uz', 'sub': sub, 'typ': 'consumer', 'exp': exp ?? testExp});

/// An [ApiClient] wired to [adapter] with base 'https://api.test/' (trailing slash on purpose).
ApiClient testClient(
  FakeAdapter adapter, {
  TokenKind kind = TokenKind.biz,
  TokenStore? store,
  UnauthorizedHandler? onUnauthorized,
  DateTime? now,
  void Function(String line)? log,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    config: ApiConfig(baseUrl: 'https://api.test/', log: log),
    tokenKind: kind,
    tokenStore: store,
    onUnauthorized: onUnauthorized,
    dio: dio,
    clock: () => now ?? testNow,
  );
}
