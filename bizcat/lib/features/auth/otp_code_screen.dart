import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/features/auth/providers.dart';
import 'package:bizcat/features/auth/widgets/auth_widgets.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Step 2 of the sign-in: the SMS code (BIZCAT-SPEC §9.2).
class OtpCodeScreen extends ConsumerStatefulWidget {
  const OtpCodeScreen({super.key, required this.phone, this.from});

  /// Normalized ('+998900000001').
  final String phone;
  final String? from;

  @override
  ConsumerState<OtpCodeScreen> createState() => _OtpCodeScreenState();
}

class _OtpCodeScreenState extends ConsumerState<OtpCodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();

  String? get _normalized => Phone.normalize(widget.phone);

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.loginWith(from: widget.from));
    }
  }

  void _onChanged(String value) {
    ref.read(loginControllerProvider.notifier).clearErrors();
    setState(() {});
    if (value.length == 6) unawaited(_submit());
  }

  Future<void> _submit() async {
    final phone = _normalized;
    final code = _code.text.trim();
    if (phone == null || code.length < 4) return;
    if (ref.read(loginControllerProvider).verifying) return;
    // Sign-in refreshes the router (which leaves /login/code), so keep the router, not the context.
    final router = GoRouter.of(context);
    final session = await ref.read(loginControllerProvider.notifier).verify(phone, code);
    if (session == null) {
      if (!mounted) return;
      if (ref.read(loginControllerProvider).codeError != null) {
        _code.clear();
        setState(() {});
        _focus.requestFocus();
      }
      return;
    }
    final from = safeFrom(widget.from);
    if (session.isNew || (session.consumer.name ?? '').isEmpty) {
      router.go(AppRoutes.loginNameWith(from: from));
    } else {
      router.go(from ?? AppRoutes.home);
    }
  }

  Future<void> _resend() async {
    final phone = _normalized;
    if (phone == null) return;
    final ok = await ref.read(loginControllerProvider.notifier).requestCode(phone);
    if (!mounted || !ok) return;
    _code.clear();
    setState(() {});
    showSnack('Kod qayta yuborildi.');
  }

  @override
  Widget build(BuildContext context) {
    final phone = _normalized;
    if (phone == null) {
      return AuthScaffold(
        onBack: _back,
        children: [
          const SizedBox(height: BzSpace.xxxl),
          EmptyState(
            icon: Icons.phone_disabled_outlined,
            title: AuthCopy.invalidPhone,
            message: 'Raqamni qaytadan kiriting.',
            actionLabel: 'Orqaga',
            onAction: () => context.go(AppRoutes.loginWith(from: widget.from)),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final state = ref.watch(loginControllerProvider);
    final ttl = state.phone == phone ? (state.ttlSec ?? 120) : 120;
    final ttlText = ttl % 60 == 0 && ttl >= 60 ? '${ttl ~/ 60} daqiqa' : '$ttl soniya';

    return AuthScaffold(
      onBack: _back,
      children: [
        const AuthHeader(title: 'Kodni kiriting'),
        const SizedBox(height: BzSpace.s),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${Phone.format(phone)} raqamiga SMS yuborildi.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            TextButton(
              onPressed: state.verifying ? null : _back,
              child: const Text("O'zgartirish"),
            ),
          ],
        ),
        const SizedBox(height: BzSpace.xl),
        AutofillGroup(
          child: TextField(
            key: const ValueKey('otp-code'),
            controller: _code,
            focusNode: _focus,
            autofocus: true,
            enabled: !state.verifying,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: BzText.sora(context, 28).copyWith(letterSpacing: 8, color: scheme.onSurface),
            onChanged: _onChanged,
            onSubmitted: (_) => unawaited(_submit()),
            decoration: InputDecoration(
              counterText: '',
              hintText: '······',
              hintStyle: BzText.sora(context, 28, color: scheme.outline).copyWith(letterSpacing: 8),
              errorText: state.codeError,
              errorMaxLines: 2,
            ),
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: BzSpace.m),
          AuthBanner(text: state.error!, kind: AuthBannerKind.error),
        ],
        const SizedBox(height: BzSpace.xl),
        CtaButton(
          label: 'Tasdiqlash',
          loading: state.verifying,
          onPressed: _code.text.trim().length >= 4 ? () => unawaited(_submit()) : null,
        ),
        const SizedBox(height: BzSpace.l),
        Center(
          child: Countdown(
            until: state.resendAvailableFor(phone),
            builder: (context, left) {
              if (left > 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: BzSpace.m),
                  child: Text(
                    'Qayta yuborish: ${formatCountdown(left)}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                );
              }
              return TextButton(
                onPressed: state.sending || state.verifying ? null : () => unawaited(_resend()),
                child: state.sending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                      )
                    : const Text('Kodni qayta yuborish'),
              );
            },
          ),
        ),
        const SizedBox(height: BzSpace.xs),
        Text(
          'Kod $ttlText amal qiladi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
