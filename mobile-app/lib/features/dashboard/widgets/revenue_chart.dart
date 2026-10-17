import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/dashboard/widgets/chart_style.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Kunlik daromad": daily revenue line (x = day, y = tiyin, labels compact so'm).
class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.series});

  final List<AnalyticsPoint> series;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dates = [for (final p in series) p.date];
    final maxY = series.fold<int>(0, (m, p) => p.revenueTiyin > m ? p.revenueTiyin : m);
    return SizedBox(
      height: DashChart.height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 100 : maxY * 1.15,
          minX: 0,
          maxX: series.isEmpty ? 0 : (series.length - 1).toDouble(),
          gridData: DashChart.grid(c),
          borderData: FlBorderData(show: false),
          titlesData: DashChart.titles(
            c: c,
            dates: dates,
            left: (v) => Money.compact(v.round(), withCurrency: false),
            leftReserved: 48,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surface2,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${UzDates.dayMonthShort(dates[s.x.round()])}\n${Money.format(s.y.round())}',
                    DashChart.tooltip(c),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].revenueTiyin.toDouble())],
              color: c.primary,
              barWidth: 2.5,
              isCurved: true,
              preventCurveOverShooting: true,
              dotData: FlDotData(show: series.length <= 31),
              belowBarData: BarAreaData(show: true, color: c.primary.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
