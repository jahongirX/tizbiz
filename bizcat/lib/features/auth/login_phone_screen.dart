import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/features/auth/providers.dart';
import 'package:bizcat/features/auth/widgets/auth_widgets.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/phone_field.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Step 1 of the sign-in: the phone number (BIZCAT-SPEC §9.2).
/// The seeded demo consumer (bookings, orders, reviews) and its fixed OTP code.
const kDemoConsumerPhone = '+998900000001';
const kDemoConsumerCode = '1111';

/// One-tap demo sign-in: `--dart-define=DEMO_LOGINS=true` (the CI APK build sets it) or debug.
const kShowDemoLogin = bool.fromEnvironment('DEMO_LOGINS') || kDebugMode;

class LoginPhoneScreen extends ConsumerStatefulWidget {
  const LoginPhoneScreen({super.key, this.from, this.expired = false});

  final String? from;
  final bool expired;

  @override
  ConsumerState<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends ConsumerState<LoginPhoneScreen> {
  final _phone = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _complete => phoneFieldDigits(_phone.text).length == 9;

  void _onChanged(String _) {
    setState(() => _localError = null);
    ref.read(loginControllerProvider.notifier).clearErrors();
  }

  Future<void> _submit() async {
    final state = ref.read(loginControllerProvider);
    if (state.sending || !_complete) return;
    final normalized = phoneFieldNormalized(_phone.text);
    if (normalized == null) {
      setState(() => _localError = AuthCopy.invalidPhone);
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await ref.read(loginControllerProvider.notifier).requestCode(normalized);
    if (!mounted || !ok) return;
    _openCode(normalized);
  }

  /// One tap demo sign-in: the demo consumer phone with its fixed code (no SMS).
  Future<void> _demo() async {
    final ctrl = ref.read(loginControllerProvider.notifier);
    if (ref.read(loginControllerProvider).busy) return;
    // Sign-in refreshes the router (which leaves /login), so keep the router, not the context.
    final router = GoRouter.of(context);
    if (!await ctrl.requestCode(kDemoConsumerPhone)) return;
    final session = await ctrl.verify(kDemoConsumerPhone, kDemoConsumerCode);
    if (session == null) return;
    router.go(safeFrom(widget.from) ?? AppRoutes.home);
  }

  void _openCode(String normalized) {
    unawaited(context.push(AppRoutes.loginCodeWith(phone: normalized, from: widget.from)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final state = ref.watch(loginControllerProvider);
    final normalized = phoneFieldNormalized(_phone.text);
    // A 429 for this very number means a code was sent moments ago: let the user enter it.
    final canEnterCode = state.rateLimited && normalized != null && state.phone == normalized;

    return AuthScaffold(
      footer: Text(
        'Davom etish orqali foydalanish shartlariga rozilik bildirasiz.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      children: [
        const AuthHeader(
          title: 'Telefon raqamingizni kiriting',
          subtitle: Text('Tasdiqlash kodini SMS orqali yuboramiz.'),
        ),
        if (widget.expired) ...[
          const SizedBox(height: BzSpace.l),
          const AuthBanner(text: 'Sessiya tugadi. Qaytadan kiring.'),
        ],
        const SizedBox(height: BzSpace.xxl),
        PhoneField(
          controller: _phone,
          autofocus: true,
          enabled: !state.sending,
          errorText: _localError ?? state.phoneError,
          onChanged: _onChanged,
          onSubmitted: (_) => unawaited(_submit()),
        ),
        if (state.error != null) ...[
          const SizedBox(height: BzSpace.m),
          AuthBanner(
            text: state.error!,
            kind: AuthBannerKind.error,
            action: canEnterCode
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                      ),
                      onPressed: () => _openCode(normalized),
                      child: const Text('Kodni kiritish'),
                    ),
                  )
                : null,
          ),
        ],
        const SizedBox(height: BzSpace.xl),
        CtaButton(label: 'Kod olish', loading: state.sending, onPressed: _complete ? () => unawaited(_submit()) : null),
        if (kShowDemoLogin) ...[
          const SizedBox(height: BzSpace.m),
          SecondaryButton(
            key: const Key('login-demo'),
            label: 'Demo mijoz sifatida kirish',
            icon: BzIcons.user,
            loading: state.verifying,
            onPressed: state.busy ? null : () => unawaited(_demo()),
          ),
        ],
      ],
    );
  }
}
