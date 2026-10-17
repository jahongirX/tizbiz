import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Ustalar / Xodimlar / Shifokorlar list (BIZNES-SPEC §9.8).
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeBusinessProvider);
    final async = ref.watch(staffListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(a?.engine.staffTerm ?? 'Xodimlar')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'staff-new',
        onPressed: () => unawaited(context.push(Routes.staffNew)),
        icon: const Icon(Icons.person_add_alt),
        label: const Text("Qo'shish"),
      ),
      body: AsyncBody<List<Staff>>(
        value: async,
        onRetry: () => ref.invalidate(staffListProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          icon: Icons.people_outline,
          title: "Hali xodimlar yo'q",
          message: "Birinchi xodimni qo'shing va uning ish vaqtini belgilang.",
          action: FilledButton.icon(
            onPressed: () => unawaited(context.push(Routes.staffNew)),
            icon: const Icon(Icons.person_add_alt),
            label: const Text("Xodim qo'shish"),
          ),
        ),
        data: (all) {
          final inactive = all.where((s) => !s.isActive).length;
          final list = _showInactive ? all : [for (final s in all) if (s.isActive) s];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(staffListProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                SwitchListTile(
                  title: const Text("Nofaollarni ko'rsatish"),
                  subtitle: inactive == 0 ? null : Text('$inactive ta nofaol'),
                  value: _showInactive,
                  onChanged: (v) => setState(() => _showInactive = v),
                ),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Faol xodim yo'q. Nofaollarni ko'rsating yoki yangisini qo'shing.", textAlign: TextAlign.center),
                  ),
                for (final s in list) _StaffTile(staff: s),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.staff});

  final Staff staff;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = staff;
    final muted = !s.isActive;
    final initials = s.name.trim().isEmpty ? '?' : s.name.trim()[0].toUpperCase();
    return ListTile(
      onTap: () => unawaited(context.push(Routes.staffDetail(s.id))),
      leading: CircleAvatar(
        backgroundColor: muted ? c.surface2 : c.primarySoft,
        foregroundColor: muted ? c.textMuted : c.primary,
        child: Text(initials),
      ),
      title: Text(s.name, style: muted ? TextStyle(color: c.textMuted) : null),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (s.specialization != null) Text(s.specialization!, style: TextStyle(color: c.textMuted)),
          Text('Komissiya ${s.commissionPercent ?? 0}%', style: TextStyle(color: c.textMuted)),
          if (s.userId != null) _Pill(text: "Hisob bog'langan", fg: c.success, bg: c.success.withValues(alpha: 0.12)),
          if (muted) _Pill(text: 'Nofaol', fg: c.textMuted, bg: c.surface2),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
