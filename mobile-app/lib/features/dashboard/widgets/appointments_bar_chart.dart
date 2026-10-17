import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/chart_style.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Daily bar chart: "Kunlik yozuvlar" (counts) and, with [formatValue], the orders' daily sums.
class AppointmentsBarChart extends StatelessWidget {
  const AppointmentsBarChart({super.key, required this.points, this.formatValue, this.formatAxis, this.color});

  /// Appointment counts per day of the analytics series.
  factory AppointmentsBarChart.fromSeries(List<AnalyticsPoint> series, {Key? key}) => AppointmentsBarChart(
        key: key,
        points: [for (final p in series) (date: p.date, value: p.appointments)],
      );

  final List<({LocalDate date, int value})> points;

  /// Tooltip value text; default `N ta`.
  final String Function(int value)? formatValue;

  /// Left axis text; default the plain number.
  final String Function(int value)? formatAxis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dates = [for (final p in points) p.date];
    final maxY = points.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    final barWidth = points.length > 45 ? 3.0 : (points.length > 14 ? 6.0 : 14.0);
    return SizedBox(
      height: DashChart.height,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY <= 0 ? 4 : (maxY * 1.15).ceilToDouble(),
          gridData: DashChart.grid(c),
          borderData: FlBorderData(show: false),
          titlesData: DashChart.titles(
            c: c,
            dates: dates,
            left: (v) => formatAxis?.call(v.round()) ?? '${v.round()}',
            leftReserved: formatAxis == null ? 28 : 48,
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surface2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${UzDates.dayMonthShort(dates[group.x])}\n'
                '${formatValue?.call(rod.toY.round()) ?? '${rod.toY.round()} ta'}',
                DashChart.tooltip(c),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value.toDouble(),
                    color: color ?? c.primary,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
