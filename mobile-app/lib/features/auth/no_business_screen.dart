import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/auth/register_link.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Signed in, but no active membership (or an unknown role).
class NoBusinessScreen extends ConsumerStatefulWidget {
  const NoBusinessScreen({super.key});

  @override
  ConsumerState<NoBusinessScreen> createState() => _NoBusinessScreenState();
}

class _NoBusinessScreenState extends ConsumerState<NoBusinessScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    setState(() => _checking = true);
    try {
      await ref.read(sessionProvider.notifier).refreshMe();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  static bool _roleUnknown(SessionState s) {
    if (s is! SessionSignedIn) return false;
    final active = s.session.active;
    if (active.businessId == null) return false;
    final role = active.role ?? s.session.activeBusiness?.role;
    return role == null || role == BizRole.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    final title = _roleUnknown(state) ? 'Rolingiz aniqlanmadi' : 'Siz hech qaysi faol biznes a\'zosi emassiz';
    return Scaffold(
      body: SafeArea(
        child: EmptyView(
          icon: Icons.storefront_outlined,
          title: title,
          message: "Biznes egasi sizni Jamoa bo'limiga qo'shishi kerak.",
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _checking ? null : _recheck,
                icon: _checking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Qayta tekshirish'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => unawaited(openRegister()),
                child: const Text("Ro'yxatdan o'tish"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
                child: const Text('Chiqish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
