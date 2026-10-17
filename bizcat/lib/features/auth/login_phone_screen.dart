import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/features/auth/providers.dart';
import 'package:bizcat/features/auth/widgets/auth_widgets.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/phone_field.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Step 1 of the sign-in: the phone number (BIZCAT-SPEC §9.2).
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
        CtaButton(
          label: 'Kod olish',
          loading: state.sending,
          onPressed: _complete ? () => unawaited(_submit()) : null,
        ),
        if (kDebugMode) ...[
          const SizedBox(height: BzSpace.l),
          Text(
            'Demo: 90 000 00 01 · kod 1111',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
