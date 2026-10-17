import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/staff_admin/actions.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/features/staff_admin/hours_model.dart';
import 'package:tizbiz_biznes/shared/data/schedule_data.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Ish vaqti tab: 7 rows Dushanba..Yakshanba, saved with one PUT (replaces the week).
class WorkingHoursEditor extends ConsumerStatefulWidget {
  const WorkingHoursEditor({super.key, required this.staffId, this.onDirtyChanged});

  final int staffId;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<WorkingHoursEditor> createState() => _WorkingHoursEditorState();
}

class _WorkingHoursEditorState extends ConsumerState<WorkingHoursEditor> {
  static final _itemPointer = RegExp(r'^items\[(\d+)\]');

  List<WorkingHours>? _source;
  HoursModel? _model;
  bool _dirty = false;
  bool _saving = false;
  bool _validated = false;
  Map<int, String> _rowErrors = const {};
  String? _banner;

  void _sync(List<WorkingHours> rows) {
    if (identical(rows, _source)) return;
    if (_dirty && _model != null) return;
    _source = rows;
    _model = HoursModel.fromRows(rows);
  }

  void _edit(HoursModel Function(HoursModel m) f) {
    final next = f(_model!);
    setState(() {
      _model = next;
      _banner = null;
      _rowErrors = _validated ? next.validate() : const {};
    });
    final dirty = next != HoursModel.fromRows(_source ?? const []);
    if (dirty != _dirty) {
      _dirty = dirty;
      widget.onDirtyChanged?.call(dirty);
    }
  }

  Future<void> _pick(int weekday, int index, {required bool start}) async {
    final i = _model!.day(weekday).intervals[index];
    final t = await pickTime(context, start ? i.start : i.end);
    if (t == null || !mounted) return;
    _edit((m) => m.setInterval(weekday, index, start ? i.copyWith(start: t) : i.copyWith(end: t)));
  }

  Future<void> _save() async {
    final m = _model!;
    final errors = m.validate();
    setState(() {
      _validated = true;
      _rowErrors = errors;
      _banner = errors.isEmpty ? null : "Xatolarni tuzating";
    });
    if (errors.isNotEmpty) return;
    if (m.allOff) {
      final ok = await confirmAction(
        context,
        title: 'Barcha ish vaqtlari o\'chiriladi. Davom etasizmi?',
        confirmLabel: "O'chirish",
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      final rows = await ref.read(staffActionsProvider).saveWorkingHours(widget.staffId, m.toInput());
      if (!mounted) return;
      setState(() {
        _source = rows;
        _model = HoursModel.fromRows(rows);
        _dirty = false;
      });
      widget.onDirtyChanged?.call(false);
      showAppSnack(context, 'Ish vaqti saqlandi');
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      final rowErrors = <int, String>{};
      final rest = <String>[];
      if (e is ApiException && e.isValidation && e.hasFieldErrors) {
        e.fieldErrors.forEach((pointer, text) {
          final match = _itemPointer.firstMatch(pointer);
          final wd = match == null ? null : m.weekdayOfItem(int.parse(match.group(1)!));
          if (wd != null) {
            rowErrors.putIfAbsent(wd, () => text);
          } else {
            rest.add(text);
          }
        });
      }
      setState(() {
        _rowErrors = rowErrors;
        _banner = rowErrors.isEmpty && rest.isEmpty ? (e is ApiException ? e.message : 'Xatolik yuz berdi.') : rest.isEmpty ? null : rest.join('\n');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workingHoursProvider(widget.staffId));
    return AsyncBody<List<WorkingHours>>(
      value: async,
      onRetry: () => ref.invalidate(workingHoursProvider(widget.staffId)),
      data: (rows) {
        _sync(rows);
        final m = _model!;
        final c = AppColors.of(context);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(workingHoursProvider(widget.staffId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if ((_source ?? const []).isEmpty && !_dirty)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: c.primary),
                    title: const Text('Ish vaqti hali belgilanmagan'),
                    subtitle: const Text('Dushanba-shanba 09:00-18:00 jadvalidan boshlang.'),
                    trailing: TextButton(
                      onPressed: () => _edit((_) => HoursModel.standard()),
                      child: const Text('Standart jadval'),
                    ),
                  ),
                ),
              for (final d in m.days)
                _DayRow(
                  day: d,
                  error: _rowErrors[d.weekday],
                  onWorking: (v) => _edit((x) => x.setWorking(d.weekday, v)),
                  onPick: (i, {required start}) => unawaited(_pick(d.weekday, i, start: start)),
                  onAdd: () => _edit((x) => x.addInterval(d.weekday)),
                  onRemove: (i) => _edit((x) => x.removeInterval(d.weekday, i)),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _edit((x) => x.copyMondayToWeekdays()),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Dushanbani ish kunlariga nusxalash'),
              ),
              const SizedBox(height: 16),
              FormErrorBanner(message: _banner),
              FilledButton(
                onPressed: _saving ? null : () => unawaited(_save()),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Saqlash'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.error,
    required this.onWorking,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
  });

  final DayHours day;
  final String? error;
  final ValueChanged<bool> onWorking;
  final void Function(int index, {required bool start}) onPick;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      decoration: BoxDecoration(
        color: day.working ? c.surface : c.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error != null ? c.danger : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(UzDates.weekdayLong(day.weekday), style: t.titleSmall)),
              Text(day.working ? 'Ish kuni' : 'Dam olish', style: t.bodySmall?.copyWith(color: c.textMuted)),
              Switch(value: day.working, onChanged: onWorking),
            ],
          ),
          if (day.working) ...[
            for (var i = 0; i < day.intervals.length; i++)
              Row(
                children: [
                  _TimeButton(time: day.intervals[i].start, onTap: () => onPick(i, start: true)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                  _TimeButton(time: day.intervals[i].end, onTap: () => onPick(i, start: false)),
                  const Spacer(),
                  if (day.intervals.length > 1)
                    IconButton(
                      tooltip: "Oraliqni o'chirish",
                      icon: Icon(Icons.close, size: 18, color: c.textMuted),
                      onPressed: () => onRemove(i),
                    ),
                ],
              ),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Oraliq')),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(error!, style: TextStyle(color: c.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.time, required this.onTap});

  final HmTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: Text(time.format()),
      );
}
