import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/auth/providers.dart';
import 'package:bizcat/features/auth/widgets/auth_widgets.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Step 3 (new accounts or no name yet): the display name (BIZCAT-SPEC §9.2).
class LoginNameScreen extends ConsumerStatefulWidget {
  const LoginNameScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginNameScreen> createState() => _LoginNameScreenState();
}

class _LoginNameScreenState extends ConsumerState<LoginNameScreen> {
  late final TextEditingController _name = TextEditingController(text: ref.read(currentConsumerProvider)?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _target => safeFrom(widget.from) ?? AppRoutes.home;

  void _onChanged(String _) => ref.read(loginControllerProvider.notifier).clearErrors();

  Future<void> _save() async {
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();
    final ok = await ref.read(loginControllerProvider.notifier).saveName(_name.text);
    if (!ok) return;
    router.go(_target);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    return AuthScaffold(
      onBack: () => context.go(_target),
      children: [
        const AuthHeader(title: 'Ismingiz nima?', subtitle: Text("Biznes sizni shu ism bilan ko'radi.")),
        const SizedBox(height: BzSpace.xxl),
        TextField(
          controller: _name,
          autofocus: true,
          enabled: !state.saving,
          maxLength: 64,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          onChanged: _onChanged,
          onSubmitted: (_) => unawaited(_save()),
          decoration: InputDecoration(labelText: 'Ism', counterText: '', errorText: state.nameError),
        ),
        if (state.error != null) ...[
          const SizedBox(height: BzSpace.m),
          AuthBanner(text: state.error!, kind: AuthBannerKind.error),
        ],
        const SizedBox(height: BzSpace.xl),
        CtaButton(label: 'Saqlash', loading: state.saving, onPressed: () => unawaited(_save())),
        const SizedBox(height: BzSpace.s),
        Center(
          child: TextButton(
            onPressed: state.saving ? null : () => context.go(_target),
            child: const Text("O'tkazib yuborish"),
          ),
        ),
      ],
    );
  }
}
