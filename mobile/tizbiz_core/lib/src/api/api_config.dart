import 'package:meta/meta.dart';

/// Base URL, timeouts and the optional request log sink.
@immutable
final class ApiConfig {
  static const String defaultBaseUrl = 'https://api.tizbiz.uz';

  const ApiConfig({
    this.baseUrl = defaultBaseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.log,
  });

  /// Reads `--dart-define=API_BASE=...` (falls back to [defaultBaseUrl]).
  /// Works because the const is evaluated when the app (which includes this package) is compiled.
  factory ApiConfig.fromEnvironment({void Function(String line)? log}) => ApiConfig(
        baseUrl: const String.fromEnvironment('API_BASE', defaultValue: defaultBaseUrl),
        log: log,
      );

  /// Without a trailing slash; paths in Endpoints start with '/v1/'.
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  /// Optional request log sink: one line per request, `"GET /v1/me/stats -> 200 (123 ms)"`.
  /// It never receives headers, query values or bodies (passwords, OTP codes, tokens).
  final void Function(String line)? log;

  /// [baseUrl] with trailing '/' removed.
  String get normalizedBaseUrl {
    var s = baseUrl.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
