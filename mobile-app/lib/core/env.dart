/// Compile-time switches (`--dart-define`).
abstract final class Env {
  /// `--dart-define=DEMO_LOGINS=true` shows demo login chips (they are also shown in debug).
  static const bool demoLogins = bool.fromEnvironment('DEMO_LOGINS');

  static const String appVersion = '0.1.0';
}
