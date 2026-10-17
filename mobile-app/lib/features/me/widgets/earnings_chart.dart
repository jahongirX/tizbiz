import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// True when no day of the series has earnings or completed bookings.
bool isSeriesEmpty(List<MeStatsPoint> series) => series.every((p) => p.earningsTiyin == 0 && p.completed == 0);

/// One bar per day of `series.earnings_tiyin`; tooltip with count / completed.
class EarningsChart extends StatelessWidget {
  const EarningsChart({super.key, required this.series});

  final List<MeStatsPoint> series;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final maxY = series.fold<int>(0, (m, p) => p.earningsTiyin > m ? p.earningsTiyin : m).toDouble();
    final barWidth = series.length > 45 ? 3.0 : (series.length > 14 ? 6.0 : 14.0);
    final axis = TextStyle(color: c.textMuted, fontSize: 10);
    final labelEvery = series.length <= 7 ? 1 : (series.length / 6).ceil();
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY <= 0 ? 100 : maxY * 1.15,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(Money.compact(v.round(), withCurrency: false), style: axis),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= series.length || i % labelEvery != 0) return const SizedBox.shrink();
                  return SideTitleWidget(meta: meta, child: Text(UzDates.dayMonthShort(series[i].date), style: axis));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.surface2,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final p = series[group.x];
                return BarTooltipItem(
                  '${UzDates.dayMonthShort(p.date)}\n${Money.format(p.earningsTiyin)}\n'
                  '${p.count} ta yozuv, ${p.completed} ta yakunlangan',
                  TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].earningsTiyin.toDouble(),
                    color: c.primary,
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
