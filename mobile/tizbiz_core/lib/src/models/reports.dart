import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../time/local_date.dart';
import '../util/json_read.dart';

const LocalDate _epochDay = LocalDate(1970, 1, 1);

/// Appointment counters: analytics.appointments and me/stats.appointments.
@immutable
final class AppointmentCounts {
  const AppointmentCounts({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.arrived = 0,
    this.completed = 0,
    this.noShow = 0,
    this.canceled = 0,
  });

  factory AppointmentCounts.fromJson(Map<String, dynamic> json) => AppointmentCounts(
        total: JsonRead.integer(json['total']),
        pending: JsonRead.integer(json['pending']),
        confirmed: JsonRead.integer(json['confirmed']),
        arrived: JsonRead.integer(json['arrived']),
        completed: JsonRead.integer(json['completed']),
        noShow: JsonRead.integer(json['no_show']),
        canceled: JsonRead.integer(json['canceled']),
      );

  final int total;
  final int pending;
  final int confirmed;
  final int arrived;
  final int completed;
  final int noShow;
  final int canceled;

  Map<String, dynamic> toJson() => {
        'total': total,
        'pending': pending,
        'confirmed': confirmed,
        'arrived': arrived,
        'completed': completed,
        'no_show': noShow,
        'canceled': canceled,
      };
}

/// GET /v1/analytics/overview (live AnalyticsController, owner/admin).
@immutable
final class AnalyticsOverview {
  const AnalyticsOverview({
    this.revenueTiyin = 0,
    this.appointments = const AppointmentCounts(),
    this.noShowRate = 0,
    this.clientsTotal = 0,
    this.clientsNew = 0,
    this.series = const [],
    this.topServices = const [],
    this.staffLoad = const [],
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final clients = JsonRead.objectOrNull(json['clients']) ?? const <String, dynamic>{};
    return AnalyticsOverview(
      revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
      appointments:
          AppointmentCounts.fromJson(JsonRead.objectOrNull(json['appointments']) ?? const <String, dynamic>{}),
      noShowRate: JsonRead.number(json['no_show_rate']),
      clientsTotal: JsonRead.integer(clients['total']),
      clientsNew: JsonRead.integer(clients['new']),
      series: JsonRead.list(json['series'], AnalyticsPoint.fromJson),
      topServices: JsonRead.list(json['top_services'], TopServiceRow.fromJson),
      staffLoad: JsonRead.list(json['staff_load'], StaffLoadRow.fromJson),
    );
  }

  final int revenueTiyin;
  final AppointmentCounts appointments;

  /// Percent, e.g. 6.25.
  final double noShowRate;

  /// json: clients.total.
  final int clientsTotal;

  /// json: clients.new.
  final int clientsNew;
  final List<AnalyticsPoint> series;
  final List<TopServiceRow> topServices;
  final List<StaffLoadRow> staffLoad;

  Map<String, dynamic> toJson() => {
        'revenue_tiyin': revenueTiyin,
        'appointments': appointments.toJson(),
        'no_show_rate': noShowRate,
        'clients': {'total': clientsTotal, 'new': clientsNew},
        'series': [for (final p in series) p.toJson()],
        'top_services': [for (final r in topServices) r.toJson()],
        'staff_load': [for (final r in staffLoad) r.toJson()],
      };
}

/// json: date (UTC day), revenue_tiyin, appointments.
@immutable
final class AnalyticsPoint {
  const AnalyticsPoint({required this.date, this.revenueTiyin = 0, this.appointments = 0});

  factory AnalyticsPoint.fromJson(Map<String, dynamic> json) => AnalyticsPoint(
        date: JsonRead.date(json['date']) ?? _epochDay,
        revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
        appointments: JsonRead.integer(json['appointments']),
      );

  final LocalDate date;
  final int revenueTiyin;
  final int appointments;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso(), 'revenue_tiyin': revenueTiyin, 'appointments': appointments};
}

/// json: service_id, name, count, revenue_tiyin.
@immutable
final class TopServiceRow {
  const TopServiceRow({required this.serviceId, required this.name, this.count = 0, this.revenueTiyin = 0});

  factory TopServiceRow.fromJson(Map<String, dynamic> json) => TopServiceRow(
        serviceId: JsonRead.integer(json['service_id']),
        name: JsonRead.string(json['name']),
        count: JsonRead.integer(json['count']),
        revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
      );

  final int serviceId;
  final String name;
  final int count;
  final int revenueTiyin;

  Map<String, dynamic> toJson() =>
      {'service_id': serviceId, 'name': name, 'count': count, 'revenue_tiyin': revenueTiyin};
}

/// json: staff_id, name, count, revenue_tiyin.
@immutable
final class StaffLoadRow {
  const StaffLoadRow({required this.staffId, required this.name, this.count = 0, this.revenueTiyin = 0});

  factory StaffLoadRow.fromJson(Map<String, dynamic> json) => StaffLoadRow(
        staffId: JsonRead.integer(json['staff_id']),
        name: JsonRead.string(json['name']),
        count: JsonRead.integer(json['count']),
        revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
      );

  final int staffId;
  final String name;
  final int count;
  final int revenueTiyin;

  Map<String, dynamic> toJson() => {'staff_id': staffId, 'name': name, 'count': count, 'revenue_tiyin': revenueTiyin};
}

/// GET /v1/payroll (live, owner/admin).
@immutable
final class PayrollReport {
  const PayrollReport({this.staff = const [], this.totalRevenueTiyin = 0, this.totalEarningsTiyin = 0});

  factory PayrollReport.fromJson(Map<String, dynamic> json) {
    final totals = JsonRead.objectOrNull(json['totals']) ?? const <String, dynamic>{};
    return PayrollReport(
      staff: JsonRead.list(json['staff'], PayrollRow.fromJson),
      totalRevenueTiyin: JsonRead.integer(totals['revenue_tiyin']),
      totalEarningsTiyin: JsonRead.integer(totals['earnings_tiyin']),
    );
  }

  final List<PayrollRow> staff;

  /// json: totals.revenue_tiyin.
  final int totalRevenueTiyin;

  /// json: totals.earnings_tiyin.
  final int totalEarningsTiyin;

  Map<String, dynamic> toJson() => {
        'staff': [for (final r in staff) r.toJson()],
        'totals': {'revenue_tiyin': totalRevenueTiyin, 'earnings_tiyin': totalEarningsTiyin},
      };
}

@immutable
final class PayrollRow {
  const PayrollRow({
    required this.staffId,
    required this.name,
    this.commissionPercent = 0,
    this.appointments = 0,
    this.revenueTiyin = 0,
    this.earningsTiyin = 0,
  });

  factory PayrollRow.fromJson(Map<String, dynamic> json) => PayrollRow(
        staffId: JsonRead.integer(json['staff_id']),
        name: JsonRead.string(json['name']),
        commissionPercent: JsonRead.integer(json['commission_percent']),
        appointments: JsonRead.integer(json['appointments']),
        revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
        earningsTiyin: JsonRead.integer(json['earnings_tiyin']),
      );

  final int staffId;
  final String name;
  final int commissionPercent;

  /// Completed count.
  final int appointments;
  final int revenueTiyin;
  final int earningsTiyin;

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'name': name,
        'commission_percent': commissionPercent,
        'appointments': appointments,
        'revenue_tiyin': revenueTiyin,
        'earnings_tiyin': earningsTiyin,
      };
}

/// GET /v1/finance/summary (live, owner/admin).
@immutable
final class FinanceSummary {
  const FinanceSummary({
    this.from,
    this.to,
    this.incomeTiyin = 0,
    this.refundsTiyin = 0,
    this.netTiyin = 0,
    this.count = 0,
    this.byProvider = const [],
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        from: JsonRead.date(json['from']),
        to: JsonRead.date(json['to']),
        incomeTiyin: JsonRead.integer(json['income_tiyin']),
        refundsTiyin: JsonRead.integer(json['refunds_tiyin']),
        netTiyin: JsonRead.integer(json['net_tiyin']),
        count: JsonRead.integer(json['count']),
        byProvider: JsonRead.list(json['by_provider'], FinanceProviderRow.fromJson),
      );

  final LocalDate? from;
  final LocalDate? to;
  final int incomeTiyin;
  final int refundsTiyin;
  final int netTiyin;
  final int count;
  final List<FinanceProviderRow> byProvider;

  Map<String, dynamic> toJson() => {
        'from': from?.toIso(),
        'to': to?.toIso(),
        'income_tiyin': incomeTiyin,
        'refunds_tiyin': refundsTiyin,
        'net_tiyin': netTiyin,
        'count': count,
        'by_provider': [for (final r in byProvider) r.toJson()],
      };
}

/// json: provider, amount_tiyin, count.
@immutable
final class FinanceProviderRow {
  const FinanceProviderRow({required this.provider, this.amountTiyin = 0, this.count = 0});

  factory FinanceProviderRow.fromJson(Map<String, dynamic> json) => FinanceProviderRow(
        provider: JsonRead.string(json['provider']),
        amountTiyin: JsonRead.integer(json['amount_tiyin']),
        count: JsonRead.integer(json['count']),
      );

  final String provider;
  final int amountTiyin;
  final int count;

  Map<String, dynamic> toJson() => {'provider': provider, 'amount_tiyin': amountTiyin, 'count': count};
}

/// GET /v1/finance/transactions rows (live; values may be strings: parse tolerantly).
@immutable
final class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    this.provider = '',
    this.type = '',
    this.status = '',
    this.amountTiyin = 0,
    this.createdAt,
    this.appointmentId,
    this.clientName,
    this.serviceName,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) => FinanceTransaction(
        id: JsonRead.integer(json['id']),
        provider: JsonRead.string(json['provider']),
        type: JsonRead.string(json['type']),
        status: JsonRead.string(json['status']),
        amountTiyin: JsonRead.integer(json['amount_tiyin']),
        createdAt: JsonRead.unix(json['created_at']),
        appointmentId: JsonRead.integerOrNull(json['appointment_id']),
        clientName: JsonRead.stringOrNull(json['client_name']),
        serviceName: JsonRead.stringOrNull(json['service_name']),
      );

  final int id;

  /// payme|click.
  final String provider;

  /// deposit|refund|float.
  final String type;

  /// created|pending|paid|canceled|refunded.
  final String status;
  final int amountTiyin;

  /// Unix.
  final DateTime? createdAt;
  final int? appointmentId;
  final String? clientName;
  final String? serviceName;

  /// deposit 'Depozit', refund 'Qaytarish', float 'Ustama'.
  String get typeLabel => switch (type) {
        'deposit' => 'Depozit',
        'refund' => 'Qaytarish',
        'float' => 'Ustama',
        _ => type,
      };

  /// created 'Yaratildi', pending 'Kutilmoqda', paid "To'langan", canceled 'Bekor qilindi',
  /// refunded 'Qaytarildi'.
  String get statusLabel => switch (status) {
        'created' => 'Yaratildi',
        'pending' => 'Kutilmoqda',
        'paid' => "To'langan",
        'canceled' => 'Bekor qilindi',
        'refunded' => 'Qaytarildi',
        _ => status,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'type': type,
        'status': status,
        'amount_tiyin': amountTiyin,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'appointment_id': appointmentId,
        'client_name': clientName,
        'service_name': serviceName,
      };
}

/// GET /v1/me/stats (BP 4.3).
@immutable
final class MeStats {
  const MeStats({
    required this.from,
    required this.to,
    this.timezone = Dates.defaultTimezone,
    required this.staffId,
    this.staffName = '',
    this.commissionPercent = 0,
    this.appointments = const AppointmentCounts(),
    this.revenueTiyin = 0,
    this.earningsTiyin = 0,
    this.clientsServed = 0,
    this.series = const [],
    this.todayTotal = 0,
    this.todayCompleted = 0,
    this.todayNextAt,
  });

  factory MeStats.fromJson(Map<String, dynamic> json) {
    final range = JsonRead.objectOrNull(json['range']) ?? const <String, dynamic>{};
    final staff = JsonRead.objectOrNull(json['staff']) ?? const <String, dynamic>{};
    final today = JsonRead.objectOrNull(json['today']) ?? const <String, dynamic>{};
    return MeStats(
      from: JsonRead.date(range['from']) ?? _epochDay,
      to: JsonRead.date(range['to']) ?? _epochDay,
      timezone: JsonRead.nonEmptyOrNull(range['timezone']) ?? Dates.defaultTimezone,
      staffId: JsonRead.integer(staff['id']),
      staffName: JsonRead.string(staff['name']),
      commissionPercent: JsonRead.integer(staff['commission_percent']),
      appointments:
          AppointmentCounts.fromJson(JsonRead.objectOrNull(json['appointments']) ?? const <String, dynamic>{}),
      revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
      earningsTiyin: JsonRead.integer(json['earnings_tiyin']),
      clientsServed: JsonRead.integer(json['clients_served']),
      series: JsonRead.list(json['series'], MeStatsPoint.fromJson),
      todayTotal: JsonRead.integer(today['total']),
      todayCompleted: JsonRead.integer(today['completed']),
      todayNextAt: JsonRead.utc(today['next_at']),
    );
  }

  /// json: range.from.
  final LocalDate from;

  /// json: range.to.
  final LocalDate to;

  /// json: range.timezone.
  final String timezone;

  /// json: staff.id.
  final int staffId;

  /// json: staff.name.
  final String staffName;

  /// json: staff.commission_percent.
  final int commissionPercent;
  final AppointmentCounts appointments;
  final int revenueTiyin;
  final int earningsTiyin;
  final int clientsServed;
  final List<MeStatsPoint> series;

  /// json: today.total.
  final int todayTotal;

  /// json: today.completed.
  final int todayCompleted;

  /// json: today.next_at (UTC string or null).
  final DateTime? todayNextAt;

  /// Writes nested 'range', 'staff', 'today' exactly as on the wire.
  Map<String, dynamic> toJson() => {
        'range': {'from': from.toIso(), 'to': to.toIso(), 'timezone': timezone},
        'staff': {'id': staffId, 'name': staffName, 'commission_percent': commissionPercent},
        'appointments': appointments.toJson(),
        'revenue_tiyin': revenueTiyin,
        'earnings_tiyin': earningsTiyin,
        'clients_served': clientsServed,
        'series': [for (final p in series) p.toJson()],
        'today': {
          'total': todayTotal,
          'completed': todayCompleted,
          'next_at': todayNextAt == null ? null : Dates.formatApiUtc(todayNextAt!),
        },
      };
}

/// json: date (business-local), count, completed, revenue_tiyin, earnings_tiyin.
@immutable
final class MeStatsPoint {
  const MeStatsPoint({
    required this.date,
    this.count = 0,
    this.completed = 0,
    this.revenueTiyin = 0,
    this.earningsTiyin = 0,
  });

  factory MeStatsPoint.fromJson(Map<String, dynamic> json) => MeStatsPoint(
        date: JsonRead.date(json['date']) ?? _epochDay,
        count: JsonRead.integer(json['count']),
        completed: JsonRead.integer(json['completed']),
        revenueTiyin: JsonRead.integer(json['revenue_tiyin']),
        earningsTiyin: JsonRead.integer(json['earnings_tiyin']),
      );

  final LocalDate date;
  final int count;
  final int completed;
  final int revenueTiyin;
  final int earningsTiyin;

  Map<String, dynamic> toJson() => {
        'date': date.toIso(),
        'count': count,
        'completed': completed,
        'revenue_tiyin': revenueTiyin,
        'earnings_tiyin': earningsTiyin,
      };
}
