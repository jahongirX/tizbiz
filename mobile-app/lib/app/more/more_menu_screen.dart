import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/redirect.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/env.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/core/theme_mode.dart';
import 'package:tizbiz_biznes/shared/widgets/business_avatar.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/theme_mode_selector.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One row of the "Ko'proq" menu.
@immutable
final class MoreMenuEntry {
  const MoreMenuEntry({required this.label, required this.icon, required this.location});

  final String label;
  final IconData icon;
  final String location;
}

/// The rows [a] may open, in menu order (BIZNES-SPEC §6.6). Each row is shown only when its
/// route guard passes.
List<MoreMenuEntry> moreMenuEntries(ActiveBusiness a) {
  final rows = <MoreMenuEntry>[
    if (a.hasStaffProfile && a.hasAppointments)
      MoreMenuEntry(
        label: 'Mening navbatlarim',
        icon: Icons.event_available_outlined,
        location: Routes.appointmentsFor(staffId: a.staffId),
      ),
    if (a.engine == Engine.medical)
      const MoreMenuEntry(label: 'Mijozlar', icon: Icons.people_outline, location: Routes.clients),
    MoreMenuEntry(label: a.engine.servicesTerm, icon: Icons.design_services_outlined, location: Routes.services),
    MoreMenuEntry(label: a.engine.staffTerm, icon: Icons.badge_outlined, location: Routes.staff),
    const MoreMenuEntry(label: 'Moliya', icon: Icons.account_balance_wallet_outlined, location: Routes.finance),
    const MoreMenuEntry(label: 'Ish haqi', icon: Icons.payments_outlined, location: Routes.payroll),
    const MoreMenuEntry(label: 'Sharhlar', icon: Icons.star_outline, location: Routes.reviews),
    const MoreMenuEntry(label: 'Onlayn-yozuv sozlamalari', icon: Icons.tune, location: Routes.settings),
    const MoreMenuEntry(label: 'Jamoa', icon: Icons.groups_outlined, location: Routes.team),
  ];
  return [for (final r in rows) if (canOpen(a, r.location)) r];
}

/// "Ko'proq": business header, the rest of the cabinet, theme and logout.
class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context, title: 'Hisobdan chiqasizmi?', confirmLabel: 'Chiqish', destructive: true);
    if (ok) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final session = ref.watch(sessionProvider);
    final signedIn = session is SessionSignedIn ? session : null;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final user = signedIn?.session.user;
    final multi = (signedIn?.session.businesses.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(title: const Text("Ko'proq")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (a != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BusinessAvatar(logo: a.logo, name: a.name, size: 48, accent: a.vertical.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('${a.vertical.label} · ${a.role.label}', style: t.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (multi) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.pickBusiness),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Biznesni almashtirish'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (a != null)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, e) in moreMenuEntries(a).indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(e.icon),
                      title: Text(e.label),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(e.location),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mavzu', style: t.titleSmall),
                  const SizedBox(height: 8),
                  ThemeModeSelector(
                    value: themeMode,
                    onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(Icons.logout, color: c.danger),
              title: Text('Chiqish', style: TextStyle(color: c.danger)),
              onTap: () => _logout(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          if (user != null) ...[
            Text(user.name, textAlign: TextAlign.center, style: t.bodyMedium),
            Text(Phone.format(user.phone), textAlign: TextAlign.center, style: t.bodySmall),
          ],
          const SizedBox(height: 4),
          Text('TizBiz Biznes ${Env.appVersion}', textAlign: TextAlign.center, style: t.bodySmall),
          if (kDebugMode)
            Text(ref.read(apiClientProvider).config.normalizedBaseUrl, textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ),
    );
  }
}
