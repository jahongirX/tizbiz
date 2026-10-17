import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/team/actions.dart';
import 'package:tizbiz_biznes/features/team/providers.dart';
import 'package:tizbiz_biznes/features/team/widgets/member_form_sheet.dart';
import 'package:tizbiz_biznes/features/team/widgets/member_tile.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Jamoa": business members. Owner (team.manage) adds/edits/removes; admin reads only.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final saved = await MemberFormSheet.show(context);
    if (saved != null && context.mounted) showAppSnack(context, "A'zo qo'shildi");
  }

  Future<void> _edit(BuildContext context, TeamMember m) async {
    final saved = await MemberFormSheet.show(context, member: m);
    if (saved != null && context.mounted) showAppSnack(context, 'Saqlandi');
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, TeamMember m) async {
    final ok = await confirmAction(context,
        title: "A'zoni jamoadan chiqarasizmi?",
        message: 'U darhol tizimdan chiqariladi.',
        confirmLabel: 'Chiqarish',
        destructive: true);
    if (!ok || !context.mounted) return;
    final isMe = m.userId == ref.read(currentUserIdProvider);
    try {
      await ref.read(teamActionsProvider).remove(m.userId);
      if (isMe) await ref.read(sessionProvider.notifier).refreshMe();
      if (context.mounted) showAppSnack(context, "A'zo jamoadan chiqarildi");
    } catch (e) {
      if (context.mounted) showAppSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    final canManage = active?.can(Permissions.teamManage) ?? false;
    final team = ref.watch(teamProvider);
    final staff = ref.watch(staffListProvider).value ?? const <Staff>[];
    final staffNames = {for (final s in staff) s.id: s.name};
    final meId = ref.watch(currentUserIdProvider);
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Jamoa')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("A'zo qo'shish"),
            )
          : null,
      body: AsyncBody<List<TeamMember>>(
        value: team,
        onRetry: () => ref.invalidate(teamProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.groups_outlined,
          title: "Jamoada hech kim yo'q",
          message: "Xodimlar va administratorlarni shu yerdan qo'shing.",
        ),
        data: (members) => RefreshIndicator(
          onRefresh: () => ref.refresh(teamProvider.future),
          child: MaxWidth(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (!canManage)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: c.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Faqat biznes egasi jamoani o\'zgartira oladi.',
                              style: TextStyle(color: c.textMuted)),
                        ),
                      ],
                    ),
                  ),
                for (final m in members) ...[
                  MemberTile(
                    member: m,
                    staffName: m.staffId == null ? null : staffNames[m.staffId],
                    isMe: m.userId == meId,
                    onAction: canManage
                        ? (a) => a == MemberAction.edit ? _edit(context, m) : _remove(context, ref, m)
                        : null,
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
