import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/env.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/auth/register_link.dart';
import 'package:tizbiz_biznes/features/auth/widgets/demo_login_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kWrongCredentials = "Telefon yoki parol noto'g'ri.";

/// Phone + password sign-in. Navigation after a successful login is done by the router redirect.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = Phone.normalize(_phone.text) ?? _phone.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).login(phone, _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isUnauthorized ? (e.detail.trim().isNotEmpty ? e.detail : kWrongCredentials) : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Xatolik yuz berdi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillDemo(String phone, String password) {
    _phone.text = Phone.formatLocal(phone);
    _password.text = password;
    unawaited(_submit());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final state = ref.watch(sessionProvider);
    final notice = state is SessionSignedOut ? state.message : null;
    final showDemo = Env.demoLogins || kDebugMode;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MaxWidth(
              max: 420,
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Image.asset('assets/brand/tizbiz-logo.png', height: 48, semanticLabel: 'TizBiz')),
                    const SizedBox(height: 24),
                    Text('Biznes kabinetiga kirish',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('TizBiz Biznes', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                    const SizedBox(height: 24),
                    if (notice != null && notice.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.warning.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: c.warning),
                            const SizedBox(width: 8),
                            Expanded(child: Text(notice)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    PhoneField(
                      controller: _phone,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Parol',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? "Parolni ko'rsatish" : 'Parolni yashirish',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Parolni kiriting' : null,
                    ),
                    const SizedBox(height: 16),
                    FormErrorBanner(message: _error),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Kirish'),
                    ),
                    if (showDemo) ...[
                      const SizedBox(height: 24),
                      DemoLoginChips(onPick: _fillDemo, enabled: !_busy),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => unawaited(openRegister()),
                      child: const Text("Biznesingizni ro'yxatdan o'tkazing"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
