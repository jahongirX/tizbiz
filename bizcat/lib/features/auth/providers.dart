import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The OTP sign-in flow (phone -> code -> optional name), shared by the three auth screens.
///
/// autoDispose: the state lives while any auth screen is on the stack, so the code screen sees
/// the resend timer set by the phone screen.
final loginControllerProvider = NotifierProvider.autoDispose<LoginController, LoginState>(LoginController.new);

/// Copy shown by the auth screens (BIZCAT-SPEC §9.2).
abstract final class AuthCopy {
  static const invalidPhone = "Telefon raqam noto'g'ri.";
  static const nameTooShort = "Ism kamida 2 ta harf bo'lsin.";
  static const nameTooLong = 'Ism 64 ta belgidan oshmasin.';
  static const wrongCode = "Kod noto'g'ri yoki muddati o'tgan.";
}

const Object _keep = Object();

@immutable
final class LoginState {
  const LoginState({
    this.sending = false,
    this.verifying = false,
    this.saving = false,
    this.phone,
    this.phoneError,
    this.codeError,
    this.nameError,
    this.error,
    this.rateLimited = false,
    this.resendAvailableAt,
    this.codeExpiresAt,
    this.ttlSec,
  });

  /// POST otp in flight.
  final bool sending;

  /// POST verify in flight.
  final bool verifying;

  /// PATCH me (name) in flight.
  final bool saving;

  /// The normalized phone of the last OTP request ('+998900000001').
  final String? phone;

  /// 422 pointer 'phone'.
  final String? phoneError;

  /// 422 pointer 'code'.
  final String? codeError;

  /// 422 pointer 'name'.
  final String? nameError;

  /// Any other failure (429, 503, 403, offline), already user-facing Uzbek.
  final String? error;

  /// The last OTP request answered 429.
  final bool rateLimited;

  /// now + retry_after_sec (or the 429 Retry-After), for [phone].
  final DateTime? resendAvailableAt;

  /// now + ttl_sec.
  final DateTime? codeExpiresAt;

  /// ttl_sec of the last sent code.
  final int? ttlSec;

  bool get busy => sending || verifying || saving;

  LoginState copyWith({
    bool? sending,
    bool? verifying,
    bool? saving,
    Object? phone = _keep,
    Object? phoneError = _keep,
    Object? codeError = _keep,
    Object? nameError = _keep,
    Object? error = _keep,
    bool? rateLimited,
    Object? resendAvailableAt = _keep,
    Object? codeExpiresAt = _keep,
    Object? ttlSec = _keep,
  }) =>
      LoginState(
        sending: sending ?? this.sending,
        verifying: verifying ?? this.verifying,
        saving: saving ?? this.saving,
        phone: identical(phone, _keep) ? this.phone : phone as String?,
        phoneError: identical(phoneError, _keep) ? this.phoneError : phoneError as String?,
        codeError: identical(codeError, _keep) ? this.codeError : codeError as String?,
        nameError: identical(nameError, _keep) ? this.nameError : nameError as String?,
        error: identical(error, _keep) ? this.error : error as String?,
        rateLimited: rateLimited ?? this.rateLimited,
        resendAvailableAt:
            identical(resendAvailableAt, _keep) ? this.resendAvailableAt : resendAvailableAt as DateTime?,
        codeExpiresAt: identical(codeExpiresAt, _keep) ? this.codeExpiresAt : codeExpiresAt as DateTime?,
        ttlSec: identical(ttlSec, _keep) ? this.ttlSec : ttlSec as int?,
      );

  /// The resend timer only applies to the phone it was issued for.
  DateTime? resendAvailableFor(String normalizedPhone) => phone == normalizedPhone ? resendAvailableAt : null;
}

/// Validates a display name: trimmed 2..64 characters. Returns the error text or null.
String? validateName(String raw) {
  final n = raw.trim();
  if (n.length < 2) return AuthCopy.nameTooShort;
  if (n.length > 64) return AuthCopy.nameTooLong;
  return null;
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  ApiClient get _api => ref.read(apiProvider);

  /// Clears the inline errors (the user is editing).
  void clearErrors() {
    final s = state;
    if (s.phoneError == null && s.codeError == null && s.nameError == null && s.error == null && !s.rateLimited) {
      return;
    }
    state = s.copyWith(phoneError: null, codeError: null, nameError: null, error: null, rateLimited: false);
  }

  /// POST Endpoints.consumerOtp, RequestAuth.none, body {"phone": "+998XXXXXXXXX"} -> OtpSent.
  ///
  /// 422 pointer 'phone' -> [LoginState.phoneError]; 429 -> error + resendAvailableAt (Retry-After);
  /// 503 and the rest -> error.
  Future<bool> requestCode(String normalizedPhone) async {
    if (state.sending) return false;
    state = state.copyWith(sending: true, phoneError: null, codeError: null, error: null, rateLimited: false);
    try {
      final sent = await _api.post<OtpSent>(
        Endpoints.consumerOtp,
        body: {'phone': normalizedPhone},
        auth: RequestAuth.none,
        decode: (d) => OtpSent.fromJson(JsonRead.object(d)),
      );
      if (!ref.mounted) return true;
      final now = DateTime.now();
      state = state.copyWith(
        sending: false,
        phone: normalizedPhone,
        resendAvailableAt: now.add(Duration(seconds: sent.retryAfterSec)),
        codeExpiresAt: now.add(Duration(seconds: sent.ttlSec)),
        ttlSec: sent.ttlSec,
      );
      return true;
    } on ApiException catch (e) {
      if (!ref.mounted) return false;
      final phoneError = e.fieldError('phone');
      if (phoneError != null) {
        state = state.copyWith(sending: false, phoneError: phoneError);
      } else if (e.isRateLimited) {
        final wait = e.retryAfter;
        state = state.copyWith(
          sending: false,
          error: e.message,
          rateLimited: true,
          phone: normalizedPhone,
          resendAvailableAt: wait == null ? state.resendAvailableFor(normalizedPhone) : DateTime.now().add(wait),
        );
      } else if (e.isValidation) {
        state = state.copyWith(sending: false, phoneError: e.message);
      } else {
        state = state.copyWith(sending: false, error: e.message);
      }
      return false;
    } on Object catch (e) {
      debugPrint('auth: requestCode failed: $e');
      if (ref.mounted) state = state.copyWith(sending: false, error: 'Xatolik yuz berdi.');
      return false;
    }
  }

  /// POST Endpoints.consumerVerify, RequestAuth.none, body {"phone","code"} -> ConsumerSession,
  /// then `sessionProvider.notifier.signIn(session)`.
  ///
  /// 422 pointer 'code' -> codeError; 403 'Hisob bloklangan.' and the rest -> error.
  Future<ConsumerSession?> verify(String normalizedPhone, String code) async {
    if (state.verifying) return null;
    state = state.copyWith(verifying: true, codeError: null, error: null, rateLimited: false);
    final session = ref.read(sessionProvider.notifier);
    try {
      final s = await _api.post<ConsumerSession>(
        Endpoints.consumerVerify,
        body: {'phone': normalizedPhone, 'code': code},
        auth: RequestAuth.none,
        decode: (d) => ConsumerSession.fromJson(JsonRead.object(d)),
      );
      await session.signIn(s);
      if (ref.mounted) state = state.copyWith(verifying: false);
      return s;
    } on ApiException catch (e) {
      if (!ref.mounted) return null;
      final codeError = e.fieldError('code');
      if (codeError != null) {
        state = state.copyWith(verifying: false, codeError: codeError);
      } else if (e.isValidation && e.fieldError('phone') == null) {
        state = state.copyWith(verifying: false, codeError: e.message);
      } else {
        state = state.copyWith(verifying: false, error: e.message);
      }
      return null;
    } on Object catch (e) {
      debugPrint('auth: verify failed: $e');
      if (ref.mounted) state = state.copyWith(verifying: false, error: 'Xatolik yuz berdi.');
      return null;
    }
  }

  /// PATCH Endpoints.consumerMe body {"name"} -> ConsumerUser -> `session.updateConsumer`.
  ///
  /// 422 pointer 'name' -> nameError; the rest -> error (a 401 signs out through the core hook).
  Future<bool> saveName(String name) async {
    if (state.saving) return false;
    final trimmed = name.trim();
    final invalid = validateName(trimmed);
    if (invalid != null) {
      state = state.copyWith(nameError: invalid);
      return false;
    }
    state = state.copyWith(saving: true, nameError: null, error: null);
    try {
      final me = await _api.patch<ConsumerUser>(
        Endpoints.consumerMe,
        body: {'name': trimmed},
        decode: (d) => ConsumerUser.fromJson(JsonRead.object(d)),
      );
      if (!ref.mounted) return true;
      ref.read(sessionProvider.notifier).updateConsumer(me);
      state = state.copyWith(saving: false);
      return true;
    } on ApiException catch (e) {
      if (!ref.mounted) return false;
      final nameError = e.fieldError('name');
      state = nameError != null
          ? state.copyWith(saving: false, nameError: nameError)
          : state.copyWith(saving: false, error: e.message);
      return false;
    } on Object catch (e) {
      debugPrint('auth: saveName failed: $e');
      if (ref.mounted) state = state.copyWith(saving: false, error: 'Xatolik yuz berdi.');
      return false;
    }
  }
}
