import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/features/staff_admin/widgets/staff_info_tab.dart';
import 'package:tizbiz_biznes/features/staff_admin/widgets/time_off_tab.dart';
import 'package:tizbiz_biznes/features/staff_admin/widgets/working_hours_editor.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Staff detail: Ma'lumot / Ish vaqti / Dam olish tabs (BIZNES-SPEC §9.8).
class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({super.key, required this.staffId, this.initialTab = 0});

  final int staffId;
  final int initialTab;

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  bool _infoDirty = false;
  bool _hoursDirty = false;

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeBusinessProvider);
    final async = ref.watch(staffListProvider);
    Staff? staff;
    for (final s in async.value ?? const <Staff>[]) {
      if (s.id == widget.staffId) staff = s;
    }
    final dirty = _infoDirty || _hoursDirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave(context, Routes.staff);
      },
      child: DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab.clamp(0, 2),
        child: Scaffold(
          appBar: AppBar(
            title: Text(staff?.name ?? a?.engine.staffTerm ?? 'Xodim'),
            bottom: staff == null
                ? null
                : const TabBar(tabs: [Tab(text: "Ma'lumot"), Tab(text: 'Ish vaqti'), Tab(text: 'Dam olish')]),
          ),
          body: AsyncBody<List<Staff>>(
            value: async,
            onRetry: () => ref.invalidate(staffListProvider),
            isEmpty: (_) => staff == null,
            empty: const EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Topilmadi.',
              message: "Bu xodim o'chirilgan yoki boshqa biznesga tegishli.",
            ),
            data: (_) => TabBarView(
              children: [
                StaffInfoTab(staff: staff!, onDirtyChanged: (d) => setState(() => _infoDirty = d)),
                WorkingHoursEditor(staffId: widget.staffId, onDirtyChanged: (d) => setState(() => _hoursDirty = d)),
                TimeOffTab(staffId: widget.staffId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
