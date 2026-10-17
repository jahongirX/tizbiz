import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:dio/dio.dart';

import '../auth/jwt_claims.dart';
import '../auth/token_store.dart';
import '../models/enums.dart';
import '../time/dates.dart';
import '../time/local_date.dart';
import '../util/idempotency.dart';
import '../util/json_read.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'endpoints.dart';

export 'package:dio/dio.dart' show CancelToken;

/// Called once per token value when an authenticated request gets a 401.
typedef UnauthorizedHandler = FutureOr<void> Function(ApiException error);

/// Turns the envelope `data` into a typed value.
typedef JsonDecoder<T> = T Function(dynamic data);

/// Whether a request carries the stored token.
enum RequestAuth {
  /// Attach the token when one is stored and valid for this client's TokenKind (default).
  auto,

  /// Never attach (login, OTP, public storefront, availability, deposit). A 401 on such a request
  /// never triggers the unauthorized hook (e.g. the login 401 'Telefon yoki parol noto'g'ri.').
  none,
}

/// The single HTTP client of an app. Pure Dart (dio picks its platform adapter itself).
final class ApiClient {
  ApiClient({
    required this.config,
    required this.tokenKind,
    TokenStore? tokenStore,
    UnauthorizedHandler? onUnauthorized,
    Dio? dio,
    DateTime Function()? clock,
  })  : _store = tokenStore ?? InMemoryTokenStore(),
        _onUnauthorized = onUnauthorized,
        _dio = dio ?? Dio(),
        _clock = clock ?? DateTime.now {
    _dio.options
      ..validateStatus = ((_) => true)
      ..responseType = ResponseType.plain
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.sendTimeout;
  }

  final ApiConfig config;

  /// TokenKind.consumer in Bizcat, TokenKind.biz in TizBiz Biznes.
  final TokenKind tokenKind;

  final TokenStore _store;
  final UnauthorizedHandler? _onUnauthorized;
  final Dio _dio;
  final DateTime Function() _clock;
  final StreamController<String?> _tokenChanges = StreamController<String?>.broadcast();

  bool _loaded = false;
  String? _token;
  Future<void>? _loading;
  final Set<String> _unauthorizedNotified = <String>{};

  static const Set<String> _allowedHeaders = {'accept', 'content-type', 'authorization', 'idempotency-key'};

  // ---------- token ----------

  /// Lazily loads the token from the store once, then serves it from memory.
  /// Returns null when absent, malformed, of the wrong TokenKind (store is cleared), or expired
  /// (store is cleared and onUnauthorized is NOT called; the app decides on next 401 / on boot).
  Future<String?> currentToken() async {
    if (!_loaded) {
      await (_loading ??= _load());
    }
    final t = _token;
    if (t == null) return null;
    final claims = JwtClaims.tryParse(t);
    if (claims == null || claims.kind != tokenKind || claims.isExpired(_clock())) {
      await _dropToken(t);
      return null;
    }
    return t;
  }

  Future<void> _load() async {
    final stored = await _store.read();
    if (!_loaded) {
      _token = (stored == null || stored.trim().isEmpty) ? null : stored.trim();
      _loaded = true;
    }
  }

  /// Clears memory + store, but only if [token] is still the current one.
  Future<void> _dropToken(String token) async {
    if (_token != token) return;
    _token = null;
    await _store.clear();
    _tokenChanges.add(null);
  }

  /// Claims of the current token (null when none).
  Future<JwtClaims?> currentClaims() async => JwtClaims.tryParse(await currentToken());

  /// Saves and caches. Throws [ArgumentError] if the token's kind != [tokenKind] (programming
  /// error: e.g. storing a business token in Bizcat). `null` == [clearToken].
  Future<void> setToken(String? token) async {
    if (token == null) return clearToken();
    final claims = JwtClaims.tryParse(token);
    if (claims == null || claims.kind != tokenKind) {
      throw ArgumentError.value(
        claims?.kind.name ?? 'malformed',
        'token',
        'Token kind does not match this client (${tokenKind.name})',
      );
    }
    _loaded = true;
    _token = token;
    _unauthorizedNotified.remove(token);
    await _store.write(token);
    _tokenChanges.add(token);
  }

  Future<void> clearToken() async {
    final had = _token != null;
    _loaded = true;
    _token = null;
    await _store.clear();
    if (had) _tokenChanges.add(null);
  }

  /// Stream of token changes (null on clear), for Riverpod auth providers.
  Stream<String?> get tokenChanges => _tokenChanges.stream;

  // ---------- requests ----------

  /// Low-level call. Every verb below delegates here.
  Future<ApiResponse<T>> request<T>(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    JsonDecoder<T>? decode,
    String? idempotencyKey,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) {
    return _send<T>(
      method,
      path,
      query: query,
      data: body == null ? null : jsonEncode(body),
      json: body != null,
      decode: decode,
      idempotencyKey: idempotencyKey,
      auth: auth,
      cancelToken: cancelToken,
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? query,
    JsonDecoder<T>? decode,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async =>
      (await request<T>('GET', path, query: query, decode: decode, auth: auth, cancelToken: cancelToken)).data;

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    JsonDecoder<T>? decode,
    String? idempotencyKey,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async =>
      (await request<T>('POST', path,
              body: body,
              query: query,
              decode: decode,
              idempotencyKey: idempotencyKey,
              auth: auth,
              cancelToken: cancelToken))
          .data;

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    JsonDecoder<T>? decode,
    String? idempotencyKey,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async =>
      (await request<T>('PUT', path,
              body: body,
              query: query,
              decode: decode,
              idempotencyKey: idempotencyKey,
              auth: auth,
              cancelToken: cancelToken))
          .data;

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    JsonDecoder<T>? decode,
    String? idempotencyKey,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async =>
      (await request<T>('PATCH', path,
              body: body,
              query: query,
              decode: decode,
              idempotencyKey: idempotencyKey,
              auth: auth,
              cancelToken: cancelToken))
          .data;

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    JsonDecoder<T>? decode,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async =>
      (await request<T>('DELETE', path,
              body: body, query: query, decode: decode, auth: auth, cancelToken: cancelToken))
          .data;

  /// `data` must be a List of maps; `meta` is read when present, else PageMeta.single(items.length).
  Future<Paged<T>> getPage<T>(
    String path,
    T Function(Map<String, dynamic> json) item, {
    Map<String, Object?>? query,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) async {
    final res = await request<List<T>>(
      'GET',
      path,
      query: query,
      decode: (d) => JsonRead.list(d, item),
      auth: auth,
      cancelToken: cancelToken,
    );
    return Paged<T>(items: res.data, meta: res.meta ?? PageMeta.single(res.data.length));
  }

  /// Non-paginated list (`{"data":[...]}`); null/[]/{} data => [].
  Future<List<T>> getList<T>(
    String path,
    T Function(Map<String, dynamic> json) item, {
    Map<String, Object?>? query,
    RequestAuth auth = RequestAuth.auto,
    CancelToken? cancelToken,
  }) =>
      get<List<T>>(path,
          query: query, decode: (d) => JsonRead.list(d, item), auth: auth, cancelToken: cancelToken);

  /// Multipart upload for POST /v1/uploads. [contentType] is REQUIRED and must be image/*
  /// (the server checks the declared type; octet-stream is rejected). Returns the `url`.
  Future<String> uploadImage(
    List<int> bytes, {
    required String filename,
    required String contentType,
    String path = Endpoints.uploads,
    CancelToken? cancelToken,
  }) async {
    final type = contentType.trim().toLowerCase();
    if (!type.startsWith('image/')) {
      throw ArgumentError.value(contentType, 'contentType', 'Must be an image/* type');
    }
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(type)),
    });
    final res = await _send<String>(
      'POST',
      path,
      data: form,
      json: false,
      decode: (d) {
        final url = JsonRead.nonEmptyOrNull(JsonRead.object(d)['url']);
        if (url == null) throw const FormatException('Upload response has no url');
        return url;
      },
      auth: RequestAuth.auto,
      cancelToken: cancelToken,
    );
    return res.data;
  }

  void close({bool force = false}) {
    _dio.close(force: force);
    unawaited(_tokenChanges.close());
  }

  // ---------- internals ----------

  Future<ApiResponse<T>> _send<T>(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? data,
    required bool json,
    JsonDecoder<T>? decode,
    String? idempotencyKey,
    required RequestAuth auth,
    CancelToken? cancelToken,
  }) async {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', 'Must start with /');
    }
    final verb = method.toUpperCase();
    final token = auth == RequestAuth.auto ? await currentToken() : null;
    final headers = <String, Object>{
      'accept': 'application/json',
      if (json) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      Idempotency.header.toLowerCase(): ?idempotencyKey,
    };
    assert(headers.keys.every(_allowedHeaders.contains), 'CORS: only the allowed headers are sent');

    final uri = _buildUri(path, query);
    final watch = Stopwatch()..start();
    // T == String keeps dio's ResponseType.plain (any other T forces ResponseType.json).
    Response<String> response;
    try {
      response = await _dio.requestUri<String>(
        uri,
        data: data,
        cancelToken: cancelToken,
        options: Options(
          method: verb,
          headers: headers,
          responseType: ResponseType.plain,
          // A send timeout without a body only produces a warning on web; disable it there.
          sendTimeout: data == null ? Duration.zero : config.sendTimeout,
        ),
      );
    } on DioException catch (e) {
      final failed = e.response;
      if (failed == null) {
        _log('$verb $path -> ${_transportKind(e.type).name} (${watch.elapsedMilliseconds} ms)');
        throw ApiException.network(_transportKind(e.type), cause: e);
      }
      final body = failed.data;
      response = Response<String>(
        requestOptions: failed.requestOptions,
        statusCode: failed.statusCode,
        headers: failed.headers,
        data: body == null ? null : (body is String ? body : jsonEncode(body)),
      );
    }
    final status = response.statusCode ?? 0;
    _log('$verb $path -> $status (${watch.elapsedMilliseconds} ms)');

    final responseHeaders = <String, List<String>>{
      for (final e in response.headers.map.entries) e.key.toLowerCase(): e.value,
    };
    final text = response.data ?? '';

    if (status >= 200 && status < 300) {
      Object? decoded;
      if (text.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } on FormatException catch (e) {
          throw ApiException(kind: ApiErrorKind.decode, status: status, cause: e);
        }
      }
      Object? payload = decoded;
      PageMeta? meta;
      if (decoded is Map && decoded.containsKey('data')) {
        payload = decoded['data'];
        final m = JsonRead.objectOrNull(decoded['meta']);
        if (m != null) meta = PageMeta.fromJson(m);
      }
      final T value;
      try {
        value = decode != null ? decode(payload) : payload as T;
      } on Object catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(kind: ApiErrorKind.decode, status: status, cause: e);
      }
      return ApiResponse<T>(statusCode: status, data: value, meta: meta, headers: responseHeaders);
    }

    Object? errorBody;
    if (text.trim().isNotEmpty) {
      try {
        errorBody = jsonDecode(text);
      } on FormatException {
        errorBody = text;
      }
    }
    final error = ApiException.fromResponse(status, errorBody, responseHeaders);
    if (status == 401 && token != null) {
      await _handleUnauthorized(token, error);
    }
    throw error;
  }

  Future<void> _handleUnauthorized(String token, ApiException error) async {
    final first = _unauthorizedNotified.add(token);
    await _dropToken(token);
    if (!first) return;
    final hook = _onUnauthorized;
    if (hook != null) await hook(error);
  }

  Uri _buildUri(String path, Map<String, Object?>? query) {
    final base = Uri.parse('${config.normalizedBaseUrl}$path');
    final params = _encodeQuery(query);
    if (params.isEmpty) return base;
    final encoded = params.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final existing = base.hasQuery ? '${base.query}&' : '';
    return base.replace(query: '$existing$encoded');
  }

  /// null dropped; bool -> '1'/'0'; LocalDate -> ISO; DateTime -> 'Y-m-d H:i:s' UTC;
  /// wire enums -> wire; everything else -> toString().
  static Map<String, String> _encodeQuery(Map<String, Object?>? query) {
    if (query == null) return const {};
    final out = <String, String>{};
    for (final e in query.entries) {
      final v = e.value;
      if (v == null) continue;
      out[e.key] = switch (v) {
        bool b => b ? '1' : '0',
        LocalDate d => d.toIso(),
        DateTime t => Dates.formatApiUtc(t),
        WireEnum w => w.wire,
        Enum n => n.name,
        _ => v.toString(),
      };
    }
    return out;
  }

  static ApiErrorKind _transportKind(DioExceptionType type) => switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          ApiErrorKind.timeout,
        DioExceptionType.cancel => ApiErrorKind.cancelled,
        _ => ApiErrorKind.network,
      };

  void _log(String line) {
    final sink = config.log;
    if (sink != null) sink(line);
  }
}
