import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/me/not_linked.dart';
import 'package:tizbiz_biznes/features/me/providers.dart';
import 'package:tizbiz_biznes/features/me/widgets/week_hours_table.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Jadvalim": own weekly hours and the days off of the next 60 days (read-only).
class MyScheduleScreen extends ConsumerWidget {
  const MyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = Text('Jadvalim');
    final a = ref.watch(activeBusinessProvider);
    if (a == null || !a.hasStaffProfile) {
      return Scaffold(appBar: AppBar(title: title), body: const StaffNotLinkedView());
    }
    final value = ref.watch(myScheduleProvider);
    if (isMeNotLinked(value.error) && !value.hasValue) {
      return Scaffold(appBar: AppBar(title: title), body: const MeNotLinkedView());
    }
    final today = ref.watch(meTodayProvider);
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: title),
      body: AsyncBody<MeSchedule>(
        value: value,
        onRetry: () => ref.invalidate(myScheduleProvider),
        data: (s) {
          final offs = [...s.timeOff]..sort((x, y) => x.date.compareTo(y.date));
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myScheduleProvider.future),
            child: MaxWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  SectionCard(
                    title: 'Ish vaqti',
                    child: s.workingHours.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('Ish vaqti belgilanmagan',
                                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                          )
                        : WeekHoursTable(hours: s.workingHours, todayWeekday: today.weekday),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Dam olish kunlari',
                    child: offs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text("Yaqin 60 kunda dam olish kunlari yo'q",
                                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                          )
                        : Column(
                            children: [
                              for (final t in offs)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.event_busy_outlined, color: c.textMuted),
                                  title: Text(UzDates.dayLabel(t.date, today: today)),
                                  subtitle: (t.reason ?? '').trim().isEmpty ? null : Text(t.reason!),
                                  trailing: Text(t.isFullDay || t.start == null || t.end == null
                                      ? "Kun bo'yi"
                                      : '${t.start!.format()} – ${t.end!.format()}'),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: c.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text("Jadvalni o'zgartirish uchun rahbaringizga murojaat qiling.",
                            style: TextStyle(color: c.textMuted, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
