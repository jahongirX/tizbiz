import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Filter bar of the appointments list: date range, staff, status and a search field.
class AppointmentsFilterBar extends ConsumerStatefulWidget {
  const AppointmentsFilterBar({super.key});

  @override
  ConsumerState<AppointmentsFilterBar> createState() => _AppointmentsFilterBarState();
}

class _AppointmentsFilterBarState extends ConsumerState<AppointmentsFilterBar> {
  late final TextEditingController _search = TextEditingController(text: ref.read(appointmentsFilterProvider).text);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange(AppointmentsFilter f) async {
    final picked = await showDateRangePicker(
      context: context,
      locale: const Locale('uz'),
      initialDateRange: DateTimeRange(start: f.from.toUtcMidnight(), end: f.to.toUtcMidnight()),
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.utc(2100),
      helpText: 'Davrni tanlang',
    );
    if (picked == null || !mounted) return;
    final from = LocalDate.fromDateTime(picked.start);
    var to = LocalDate.fromDateTime(picked.end);
    if (from.daysUntil(to) + 1 > kAppointmentsMaxDays) {
      to = from.addDays(kAppointmentsMaxDays - 1);
      showAppSnack(context, 'Davr $kAppointmentsMaxDays kundan oshmasligi kerak.');
    }
    ref.read(appointmentsFilterProvider.notifier).setRange(from, to);
  }

  Future<void> _pickStaff(List<Staff> staff, int? current) async {
    final result = await showModalBottomSheet<({int? id})>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ChoiceSheet<int?>(
        title: 'Xodim',
        current: current,
        options: [(value: null, label: 'Barcha xodimlar'), for (final s in staff) (value: s.id, label: s.name)],
        onSelected: (v) => Navigator.of(ctx).pop((id: v)),
      ),
    );
    if (result == null || !mounted) return;
    ref.read(appointmentsFilterProvider.notifier).setStaff(result.id);
  }

  Future<void> _pickStatus(AppointmentStatus? current) async {
    final result = await showModalBottomSheet<({AppointmentStatus? status})>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ChoiceSheet<AppointmentStatus?>(
        title: 'Holat',
        current: current,
        options: [
          (value: null, label: 'Barcha holatlar'),
          for (final s in AppointmentStatus.values)
            if (s != AppointmentStatus.unknown) (value: s, label: s.label),
        ],
        onSelected: (v) => Navigator.of(ctx).pop((status: v)),
      ),
    );
    if (result == null || !mounted) return;
    ref.read(appointmentsFilterProvider.notifier).setStatus(result.status);
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(appointmentsFilterProvider);
    final staff = ref.watch(activeStaffProvider).value ?? const <Staff>[];
    String? staffName;
    for (final s in staff) {
      if (s.id == f.staffId) staffName = s.name;
    }
    final rangeLabel = f.from == f.to
        ? UzDates.dayMonthShort(f.from)
        : '${UzDates.dayMonthShort(f.from)} – ${UzDates.dayMonthShort(f.to)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(rangeLabel),
                  onPressed: () => _pickRange(f),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(staffName ?? (f.staffId == null ? 'Barcha xodimlar' : 'Xodim #${f.staffId}')),
                  onPressed: () => _pickStaff(staff, f.staffId),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.filter_list, size: 18),
                  label: Text(f.status?.label ?? 'Barcha holatlar'),
                  onPressed: () => _pickStatus(f.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Mijoz, telefon yoki xizmat',
              suffixIcon: f.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Tozalash',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        ref.read(appointmentsFilterProvider.notifier).setText('');
                      },
                    ),
            ),
            onChanged: (v) => ref.read(appointmentsFilterProvider.notifier).setText(v),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.current, required this.options, required this.onSelected});

  final String title;
  final T current;
  final List<({T value, String label})> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final o in options)
          ListTile(
            title: Text(o.label),
            trailing: o.value == current ? const Icon(Icons.check) : null,
            onTap: () => onSelected(o.value),
          ),
      ],
    ),
  );
}
