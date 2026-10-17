import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('analytics overview', () {
    final a = AnalyticsOverview.fromJson(dataMap(analyticsJson));
    expect(a.noShowRate, 0.0);
    expect(a.noShowRate, isA<double>());
    expect(a.series, hasLength(3));
    expect(a.series.first.revenueTiyin, 0);
    expect(a.series.first.date, const LocalDate(2026, 10, 15));
    expect(a.appointments.completed, 6);
    expect(a.clientsTotal, 120);
    expect(a.clientsNew, 4);
    expect(a.topServices.single.serviceId, 11);
    expect(a.staffLoad.single.count, 8);
    expect(a.toJson()['clients'], {'total': 120, 'new': 4});
    expectFixedPoint(a, (x) => x.toJson(), AnalyticsOverview.fromJson);
  });

  test('payroll', () {
    final p = PayrollReport.fromJson(dataMap(payrollJson));
    expect(p.totalRevenueTiyin, 48000000);
    expect(p.totalEarningsTiyin, 19200000);
    expect(p.staff.single.commissionPercent, 40);
    expectFixedPoint(p, (x) => x.toJson(), PayrollReport.fromJson);
  });

  test('finance summary', () {
    final f = FinanceSummary.fromJson(dataMap(financeSummaryJson));
    expect(f.from, const LocalDate(2026, 9, 18));
    expect(f.to, const LocalDate(2026, 10, 17));
    expect(f.netTiyin, 6000000);
    expect(f.byProvider.single.provider, 'payme');
    expectFixedPoint(f, (x) => x.toJson(), FinanceSummary.fromJson);
  });

  test('finance transaction with string values', () {
    final t = FinanceTransaction.fromJson(dataList(financeTransactionsJson).single);
    expect(t.id, 301);
    expect(t.amountTiyin, 2000000);
    expect(t.appointmentId, 5012);
    expect(t.createdAt, Dates.fromUnix(1792213920));
    expect(t.typeLabel, 'Depozit');
    expect(t.statusLabel, "To'langan");
    expectFixedPoint(t, (x) => x.toJson(), FinanceTransaction.fromJson);
  });

  test('me/stats', () {
    final s = MeStats.fromJson(dataMap(meStatsJson));
    expect(s.from, const LocalDate(2026, 10, 1));
    expect(s.to, const LocalDate(2026, 10, 17));
    expect(s.timezone, 'Asia/Tashkent');
    expect(s.staffId, 2);
    expect(s.commissionPercent, 40);
    expect(s.appointments.noShow, 4);
    expect(s.todayNextAt, DateTime.utc(2026, 10, 17, 9, 30));
    expect(s.series.first.earningsTiyin, 9600000);
    final json = s.toJson();
    expect(json['range'], {'from': '2026-10-01', 'to': '2026-10-17', 'timezone': 'Asia/Tashkent'});
    expect(json['staff'], {'id': 2, 'name': 'Usta Jahongir', 'commission_percent': 40});
    expect(json['today'], {'total': 6, 'completed': 2, 'next_at': '2026-10-17 09:30:00'});
    expectFixedPoint(s, (x) => x.toJson(), MeStats.fromJson);
  });
}
