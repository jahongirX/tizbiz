import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Picks any of the 6 board statuses (the server has no transition rules). Choosing
/// "Bekor qilingan" asks for confirmation. Returns null when dismissed or unchanged.
Future<OrderStatus?> showOrderStatusPicker(BuildContext context, OrderStatus current) async {
  final picked = await showModalBottomSheet<OrderStatus>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatusPickerSheet(current: current),
  );
  if (picked == null || picked == current || !context.mounted) return null;
  if (picked == OrderStatus.cancelled && !await confirmCancelOrder(context)) return null;
  return picked;
}

/// "Buyurtma bekor qilinsinmi?" (destructive).
Future<bool> confirmCancelOrder(BuildContext context) => confirmAction(
  context,
  title: 'Buyurtma bekor qilinsinmi?',
  message: 'Mijozga buyurtma bekor qilingani ko\'rinadi.',
  confirmLabel: 'Bekor qilish',
  destructive: true,
);

class StatusPickerSheet extends StatelessWidget {
  const StatusPickerSheet({super.key, required this.current});

  final OrderStatus current;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text("Holatni o'zgartirish", style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final s in OrderStatus.board)
            ListTile(
              leading: Icon(Icons.circle, size: 12, color: c.orderStatusColor(s)),
              title: Text(s.label),
              trailing: s == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(s),
            ),
        ],
      ),
    );
  }
}
