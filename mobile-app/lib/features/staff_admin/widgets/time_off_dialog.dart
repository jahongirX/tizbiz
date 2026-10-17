import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/staff_admin/actions.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Add one time-off row; pops with the created [TimeOff].
class TimeOffDialog extends ConsumerStatefulWidget {
  const TimeOffDialog({super.key, required this.staffId, required this.today});

  final int staffId;
  final LocalDate today;

  static Future<TimeOff?> show(BuildContext context, {required int staffId, required LocalDate today}) =>
      showDialog<TimeOff>(context: context, builder: (_) => TimeOffDialog(staffId: staffId, today: today));

  @override
  ConsumerState<TimeOffDialog> createState() => _TimeOffDialogState();
}

class _TimeOffDialogState extends ConsumerState<TimeOffDialog> {
  final _reason = TextEditingController();
  LocalDate? _date;
  bool _fullDay = true;
  HmTime _start = const HmTime(10, 0);
  HmTime _end = const HmTime(14, 0);
  bool _saving = false;
  bool _submitted = false;
  Map<String, String> _fieldErrors = const {};
  String? _banner;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? get _dateError {
    if (_fieldErrors['date'] != null) return _fieldErrors['date'];
    if (!_submitted) return null;
    if (_date == null) return 'Sanani tanlang';
    if (_date!.isBefore(widget.today)) return "O'tgan sanani tanlab bo'lmaydi";
    return null;
  }

  String? get _timeError {
    final server = _fieldErrors['start_time'] ?? _fieldErrors['end_time'];
    if (server != null) return server;
    if (!_submitted || _fullDay) return null;
    return _start.compareTo(_end) < 0 ? null : "Boshlanish vaqti tugash vaqtidan oldin bo'lishi kerak";
  }

  Future<void> _pickDate() async {
    final t = widget.today;
    final initial = _date ?? t;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(t.year, t.month, t.day),
      lastDate: DateTime(t.year + 2, 12, 31),
      locale: const Locale('uz'),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = LocalDate.fromDateTime(picked);
        _fieldErrors = const {};
      });
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final t = await pickTime(context, start ? _start : _end);
    if (t == null || !mounted) return;
    setState(() {
      if (start) {
        _start = t;
      } else {
        _end = t;
      }
      _fieldErrors = const {};
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    if (_dateError != null || _timeError != null) return;
    final reason = _reason.text.trim();
    final input = TimeOffInput(
      date: _date!,
      start: _fullDay ? null : _start,
      end: _fullDay ? null : _end,
      reason: reason.isEmpty ? null : reason,
    );
    setState(() => _saving = true);
    try {
      final created = await ref.read(staffActionsProvider).addTimeOff(widget.staffId, input);
      if (mounted) Navigator.of(context).pop(created);
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      final split = splitFormError(e, const {'date', 'start_time', 'end_time', 'reason'});
      setState(() {
        _fieldErrors = split.fields;
        _banner = split.banner;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dateError = _dateError;
    final timeError = _timeError;
    return AlertDialog(
      title: const Text("Dam olish qo'shish"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => unawaited(_pickDate()),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Sana',
                  errorText: dateError,
                  suffixIcon: const Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_date == null ? 'Tanlang' : UzDates.dayMonthYear(_date!),
                    style: TextStyle(color: _date == null ? c.textMuted : c.text)),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Kun bo'yi"),
              value: _fullDay,
              onChanged: (v) => setState(() => _fullDay = v),
            ),
            if (!_fullDay) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_pickTime(start: true)),
                      child: Text('Boshlanish ${_start.format()}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_pickTime(start: false)),
                      child: Text('Tugash ${_end.format()}'),
                    ),
                  ),
                ],
              ),
              if (timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(timeError, style: TextStyle(color: c.danger, fontSize: 12)),
                ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _reason,
              maxLength: 160,
              decoration: InputDecoration(labelText: 'Sabab', hintText: "Ta'til, kasallik...", errorText: _fieldErrors['reason']),
            ),
            FormErrorBanner(message: _banner),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Bekor')),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_submit()),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}
