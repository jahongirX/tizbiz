import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const _bucketLabels = {'morning': 'Ertalab', 'afternoon': 'Kunduzi', 'evening': 'Kechqurun'};

/// Free slots of a staff/service/date as chips grouped by part of day, plus "Boshqa vaqt"
/// (a manual 24 h time; admin mode skips the slot check).
class SlotPicker extends ConsumerWidget {
  const SlotPicker({
    super.key,
    required this.staffId,
    required this.serviceId,
    required this.date,
    required this.selectedSlot,
    required this.manualTime,
    required this.onSlot,
    required this.onManual,
    this.errorMessage,
  });

  final int? staffId;
  final int? serviceId;
  final LocalDate date;
  final AvailabilitySlot? selectedSlot;
  final HmTime? manualTime;
  final ValueChanged<AvailabilitySlot> onSlot;
  final ValueChanged<HmTime> onManual;
  final String? errorMessage;

  Future<void> _pickManual(BuildContext context) async {
    final initial = manualTime ?? selectedSlot?.startLocal ?? const HmTime(10, 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'Vaqtni tanlang',
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) onManual(HmTime(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final manualChip = ChoiceChip(
      avatar: const Icon(Icons.schedule, size: 18),
      label: Text(manualTime == null ? 'Boshqa vaqt' : 'Boshqa vaqt: ${manualTime!.format()}'),
      selected: manualTime != null,
      onSelected: (_) => _pickManual(context),
    );
    final error = errorMessage == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(errorMessage!, style: t.bodySmall?.copyWith(color: c.danger)),
          );
    if (staffId == null || serviceId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bo'sh vaqtlarni ko'rish uchun xodim va xizmatni tanlang.",
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 8),
          manualChip,
          ?error,
        ],
      );
    }
    final key = (staffId: staffId!, serviceId: serviceId!, date: date);
    final value = ref.watch(availabilityProvider(key));
    final Widget slots;
    if (value.hasValue) {
      final list = value.requireValue.slots;
      if (list.isEmpty) {
        slots = Text(
          "Bo'sh vaqt yo'q. Boshqa vaqtni qo'lda tanlang.",
          style: t.bodySmall?.copyWith(color: c.textMuted),
        );
      } else {
        final groups = <String, List<AvailabilitySlot>>{};
        for (final s in list) {
          groups.putIfAbsent(s.bucket, () => []).add(s);
        }
        slots = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in const ['morning', 'afternoon', 'evening'])
              if (groups[b] != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(_bucketLabels[b]!, style: t.labelMedium?.copyWith(color: c.textMuted)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in groups[b]!)
                      ChoiceChip(
                        label: Text(s.startLocal.format()),
                        selected: manualTime == null && selectedSlot?.startUtc == s.startUtc,
                        onSelected: (_) => onSlot(s),
                      ),
                  ],
                ),
              ],
          ],
        );
      }
    } else if (value.hasError) {
      slots = Row(
        children: [
          Expanded(
            child: Text(
              "Bo'sh vaqtlar yuklanmadi: ${errorText(value.error!)}",
              style: t.bodySmall?.copyWith(color: c.danger),
            ),
          ),
          TextButton(onPressed: () => ref.invalidate(availabilityProvider(key)), child: const Text('Qayta urinish')),
        ],
      );
    } else {
      slots = const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [slots, const SizedBox(height: 8), manualChip, ?error],
    );
  }
}
