import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/env.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/core/theme_mode.dart';
import 'package:tizbiz_biznes/features/me/not_linked.dart';
import 'package:tizbiz_biznes/features/me/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/business_avatar.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_biznes/shared/widgets/theme_mode_selector.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Profil" (staff): user, business, own staff row, business switch, theme, logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Tizimdan chiqasizmi?', confirmLabel: 'Chiqish', destructive: true);
    if (ok) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final session = ref.watch(sessionProvider);
    final a = ref.watch(activeBusinessProvider);
    final auth = session is SessionSignedIn ? session.session : null;
    final user = auth?.user;
    final businessCount = auth?.businesses.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (user != null)
              SectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: c.primarySoft,
                      child: Text(BusinessAvatar.initials(user.name), style: TextStyle(color: c.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(Phone.format(user.phone), style: TextStyle(color: c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (a != null) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: 'Biznes',
                child: Row(
                  children: [
                    BusinessAvatar(logo: a.logo, name: a.name, accent: a.vertical.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${a.vertical.label} · ${a.role.label}', style: TextStyle(color: c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (a.hasStaffProfile) const _StaffCard() else const StaffNotLinkedView(compact: true),
            ],
            if (businessCount > 1) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Biznesni almashtirish'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => unawaited(context.push(Routes.pickBusiness)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: 'Mavzu',
              child: ThemeModeSelector(
                value: ref.watch(themeModeProvider),
                onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: c.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text("Parolni o'zgartirish uchun biznes egasiga murojaat qiling.",
                      style: TextStyle(color: c.textMuted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              style: OutlinedButton.styleFrom(foregroundColor: c.danger),
              icon: const Icon(Icons.logout),
              label: const Text('Chiqish'),
            ),
            const SizedBox(height: 16),
            Center(child: Text('Versiya ${Env.appVersion}', style: TextStyle(color: c.textMuted, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final value = ref.watch(meStaffProvider);
    if (isMeNotLinked(value.error) && !value.hasValue) return const MeNotLinkedView(compact: true);
    return SectionCard(
      title: 'Xodim profili',
      child: switch (value) {
        AsyncValue(hasValue: true, :final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((value.specialization ?? '').isNotEmpty)
                Text(value.specialization!, style: TextStyle(color: c.textMuted)),
              const SizedBox(height: 4),
              Text('Komissiya ${value.commissionPercent ?? 0}%'),
            ],
          ),
        AsyncValue(:final error?) => Row(
            children: [
              Expanded(child: Text(errorText(error), style: TextStyle(color: c.danger))),
              TextButton(onPressed: () => ref.invalidate(meStaffProvider), child: const Text('Qayta urinish')),
            ],
          ),
        _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      },
    );
  }
}
