import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Shared axis styling for the dashboard charts (fl_chart needs explicit colours and styles).
abstract final class DashChart {
  static const double height = 180;

  static TextStyle axis(AppColors c) => TextStyle(color: c.textMuted, fontSize: 10);

  static TextStyle tooltip(AppColors c) => TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600);

  /// Label every n-th day so at most ~6 labels fit.
  static int labelStep(int points) => points <= 7 ? 1 : (points / 6).ceil();

  static FlTitlesData titles({
    required AppColors c,
    required List<LocalDate> dates,
    required String Function(double value) left,
    required double leftReserved,
  }) {
    final step = labelStep(dates.length);
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: leftReserved,
          getTitlesWidget: (value, meta) => value == meta.max && value != 0 && meta.max % meta.appliedInterval != 0
              ? const SizedBox.shrink()
              : SideTitleWidget(meta: meta, child: Text(left(value), style: axis(c))),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if (i < 0 || i >= dates.length || value != i.toDouble() || i % step != 0) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(meta: meta, child: Text(UzDates.dayMonthShort(dates[i]), style: axis(c)));
          },
        ),
      ),
    );
  }

  static FlGridData grid(AppColors c) => FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
      );
}
