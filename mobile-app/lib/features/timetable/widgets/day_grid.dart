import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/timetable/layout.dart';
import 'package:tizbiz_biznes/features/timetable/widgets/appointment_block.dart';
import 'package:tizbiz_biznes/features/timetable/widgets/staff_header.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Everything one staff column shows for the selected day.
final class StaffColumnData {
  const StaffColumnData({required this.staff, this.appointments = const [], this.hours = const [], this.timeOff = const []});

  final Staff staff;
  final List<Appointment> appointments;

  /// Working hours of the day's weekday only.
  final List<WorkingHours> hours;

  /// Time-off rows of the selected date only.
  final List<TimeOff> timeOff;
}

/// Sticky staff header + time gutter + one column per staff; scrolls both ways.
class DayGrid extends StatefulWidget {
  const DayGrid({
    super.key,
    required this.day,
    required this.columns,
    required this.range,
    required this.business,
    required this.onRefresh,
    this.nowMin,
    this.onTapAppointment,
    this.onTapEmpty,
  });

  final LocalDate day;
  final List<StaffColumnData> columns;
  final ({int startMin, int endMin}) range;
  final ActiveBusiness business;
  final Future<void> Function() onRefresh;

  /// Local minute-of-day of "now" when [day] is today (draws the now line).
  final int? nowMin;
  final ValueChanged<Appointment>? onTapAppointment;

  /// Null when the user may not create appointments.
  final void Function(Staff staff, HmTime time)? onTapEmpty;

  @override
  State<DayGrid> createState() => _DayGridState();
}

class _DayGridState extends State<DayGrid> {
  final _vertical = ScrollController();
  final _hBody = ScrollController();
  final _hHeader = ScrollController();
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    _hBody.addListener(() {
      if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) _hHeader.jumpTo(_hBody.offset);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPosition());
  }

  @override
  void didUpdateWidget(DayGrid old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day) {
      _positioned = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPosition());
    }
  }

  void _autoPosition() {
    if (!mounted || _positioned || !_vertical.hasClients) return;
    _positioned = true;
    final now = widget.nowMin;
    var target = 0.0;
    if (now != null && now > widget.range.startMin) {
      target = minuteToY(now, widget.range.startMin) - kHourPx;
    }
    _vertical.jumpTo(target.clamp(0, _vertical.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _vertical.dispose();
    _hBody.dispose();
    _hHeader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = widget.range;
    final height = minuteToY(r.endMin, r.startMin);
    return LayoutBuilder(builder: (context, box) {
      final n = math.max(1, widget.columns.length);
      final colW = math.max(kMinColumnPx, (box.maxWidth - kGutterPx) / n);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: kGutterPx,
                height: 52,
                decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
              ),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: SingleChildScrollView(
                    controller: _hHeader,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(children: [for (final col in widget.columns) StaffHeader(staff: col.staff, width: colW)]),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: SingleChildScrollView(
                controller: _vertical,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeGutter(range: r, height: height, nowMin: widget.nowMin),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hBody,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final col in widget.columns)
                              _StaffColumn(
                                data: col,
                                width: colW,
                                height: height,
                                range: r,
                                day: widget.day,
                                business: widget.business,
                                nowMin: widget.nowMin,
                                onTapAppointment: widget.onTapAppointment,
                                onTapEmpty: widget.onTapEmpty,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({required this.range, required this.height, this.nowMin});

  final ({int startMin, int endMin}) range;
  final double height;
  final int? nowMin;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextStyle(fontSize: 11, color: c.textMuted);
    return SizedBox(
      width: kGutterPx,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var m = range.startMin; m < range.endMin; m += 60)
            Positioned(
              top: minuteToY(m, range.startMin) + 2,
              left: 0,
              right: 6,
              child: Text(HmTime.fromMinutes(m).format(), textAlign: TextAlign.right, style: style),
            ),
        ],
      ),
    );
  }
}

class _StaffColumn extends StatelessWidget {
  const _StaffColumn({
    required this.data,
    required this.width,
    required this.height,
    required this.range,
    required this.day,
    required this.business,
    this.nowMin,
    this.onTapAppointment,
    this.onTapEmpty,
  });

  final StaffColumnData data;
  final double width;
  final double height;
  final ({int startMin, int endMin}) range;
  final LocalDate day;
  final ActiveBusiness business;
  final int? nowMin;
  final ValueChanged<Appointment>? onTapAppointment;
  final void Function(Staff staff, HmTime time)? onTapEmpty;

  double _y(int min) => minuteToY(min.clamp(range.startMin, range.endMin), range.startMin);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tz = business.timezone;
    final lanes = computeLanes(data.appointments, tz);
    final tapEmpty = onTapEmpty;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.surface2, border: Border(left: BorderSide(color: c.border))),
      child: Stack(
        children: [
          for (final h in data.hours)
            Positioned(
              top: _y(h.start.minutesOfDay),
              height: math.max(0, _y(h.end.minutesOfDay) - _y(h.start.minutesOfDay)),
              left: 0,
              right: 0,
              child: ColoredBox(color: c.surface),
            ),
          for (var m = range.startMin + 60; m < range.endMin; m += 60)
            Positioned(top: _y(m), left: 0, right: 0, child: Container(height: 1, color: c.border)),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: tapEmpty == null ? null : (d) => tapEmpty(data.staff, snapToSlot(d.localPosition.dy, range.startMin)),
            ),
          ),
          for (final t in data.timeOff) _timeOff(context, t),
          for (final a in data.appointments) _block(a, lanes[a.id] ?? (lane: 0, lanes: 1), tz),
          if (nowMin != null && nowMin! >= range.startMin && nowMin! <= range.endMin)
            Positioned(
              top: _y(nowMin!) - 1,
              left: 0,
              right: 0,
              child: IgnorePointer(child: Container(height: 2, color: c.danger)),
            ),
        ],
      ),
    );
  }

  Widget _timeOff(BuildContext context, TimeOff t) {
    final c = AppColors.of(context);
    final top = t.isFullDay ? 0.0 : _y(t.start?.minutesOfDay ?? range.startMin);
    final bottom = t.isFullDay ? height : _y(t.end?.minutesOfDay ?? range.endMin);
    final label = (t.reason ?? '').trim().isEmpty ? 'Dam olish' : t.reason!.trim();
    return Positioned(
      top: top,
      height: math.max(16, bottom - top),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _HatchPainter(color: c.textMuted.withValues(alpha: 0.25)),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textMuted, fontStyle: FontStyle.italic)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _block(Appointment a, ({int lane, int lanes}) l, String tz) {
    final top = _y(apptStartMin(a, day, tz));
    final h = math.max(kMinBlockPx, _y(apptEndMin(a, day, tz)) - top);
    final laneW = width / l.lanes;
    return Positioned(
      top: top,
      height: h,
      left: laneW * l.lane + 2,
      width: math.max(8, laneW - 4),
      child: AppointmentBlock(
        appointment: a,
        business: business,
        height: h,
        onTap: onTapAppointment == null ? null : () => onTapAppointment!(a),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}
