import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

enum MemberAction { edit, remove }

/// One team member row: name, phone, role badge, linked staff, "Siz" chip, owner menu.
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    this.staffName,
    this.isMe = false,
    this.onAction,
  });

  final TeamMember member;

  /// Name of the linked staff row (null while unknown).
  final String? staffName;
  final bool isMe;

  /// Null = read-only (no menu).
  final ValueChanged<MemberAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = (member.name ?? '').trim().isEmpty ? 'Nomsiz' : member.name!;
    final linked = member.staffId == null
        ? Text("Xodimga bog'lanmagan", style: TextStyle(color: c.textMuted, fontSize: 13))
        : Text('Xodim: ${staffName ?? '#${member.staffId}'}', style: const TextStyle(fontSize: 13));
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (isMe) ...[
            const SizedBox(width: 6),
            _Pill(text: 'Siz', bg: c.primarySoft, fg: c.primary),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((member.phone ?? '').isNotEmpty) Text(Phone.format(member.phone)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(text: member.role.label, bg: c.surface2, fg: c.text),
              linked,
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: onAction == null
          ? null
          : PopupMenuButton<MemberAction>(
              tooltip: 'Amallar',
              onSelected: onAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: MemberAction.edit, child: Text('Tahrirlash')),
                PopupMenuItem(value: MemberAction.remove, child: Text('Chiqarish')),
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
