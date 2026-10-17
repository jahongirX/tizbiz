import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One cell of the sticky header row: staff name + specialization.
class StaffHeader extends StatelessWidget {
  const StaffHeader({super.key, required this.staff, required this.width});

  final Staff staff;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(left: BorderSide(color: c.border), bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(staff.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            staff.specialization ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
