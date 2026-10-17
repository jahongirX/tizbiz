import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/app/theme/vertical.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/business_avatar.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Picks the active business (after login with several memberships, or from the switcher).
class BusinessPickerScreen extends ConsumerStatefulWidget {
  const BusinessPickerScreen({super.key});

  @override
  ConsumerState<BusinessPickerScreen> createState() => _BusinessPickerScreenState();
}

class _BusinessPickerScreenState extends ConsumerState<BusinessPickerScreen> {
  bool _busy = false;

  Future<void> _pick(BusinessMembership m, int? activeId) async {
    if (_busy) return;
    final session = ref.read(sessionProvider.notifier);
    if (m.id == activeId) {
      session.completePicker();
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))),
      ),
    ));
    Object? error;
    try {
      await session.switchBusiness(m.id);
    } catch (e) {
      error = e;
    }
    if (nav.mounted && nav.canPop()) nav.pop();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) showAppSnack(context, errorText(error), error: true);
  }

  Future<void> _logout() => ref.read(sessionProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final state = ref.watch(sessionProvider);
    final signedIn = state is SessionSignedIn ? state : null;
    final businesses = signedIn?.session.businesses ?? const <BusinessMembership>[];
    final activeId = signedIn?.session.active.businessId;
    final needsPicker = signedIn?.needsPicker ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biznesni tanlang'),
        automaticallyImplyLeading: !needsPicker,
        actions: [TextButton(onPressed: _busy ? null : _logout, child: const Text('Chiqish'))],
      ),
      body: businesses.isEmpty
          ? const EmptyView(icon: Icons.storefront_outlined, title: 'Bizneslar topilmadi')
          : MaxWidth(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = businesses[i];
                  final v = Vertical.of(category: m.category, engine: m.engine);
                  final active = m.id == activeId;
                  return ListTile(
                    enabled: !_busy,
                    leading: BusinessAvatar(logo: m.logo, name: m.name, accent: v.accent),
                    title: Text(m.name),
                    subtitle: Text('${v.label} · ${m.role.label}'),
                    trailing: active
                        ? Chip(
                            label: const Text('Faol'),
                            backgroundColor: c.primarySoft,
                            labelStyle: TextStyle(color: c.primary, fontWeight: FontWeight.w600),
                            visualDensity: VisualDensity.compact,
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => _pick(m, activeId),
                  );
                },
              ),
            ),
    );
  }
}
