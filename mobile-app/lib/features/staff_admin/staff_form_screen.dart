import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/features/staff_admin/actions.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/features/staff_admin/widgets/staff_info_tab.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';

/// Create a staff member; on success opens the detail on the Ish vaqti tab.
class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave(context, Routes.staff);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Yangi xodim')),
        body: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StaffFieldsForm(
                submitLabel: "Qo'shish",
                onDirtyChanged: (d) => setState(() => _dirty = d),
                onSubmit: (body) async {
                  final s = await ref.read(staffActionsProvider).create(body);
                  if (!context.mounted) return;
                  setState(() => _dirty = false);
                  showAppSnack(context, "Xodim qo'shildi. Endi ish vaqtini belgilang.");
                  context.pushReplacement(Routes.staffDetail(s.id, tab: 1));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
