import '../models/enums.dart';
import '../time/dates.dart';
import '../time/local_date.dart';

/// One place for the four date encodings the API uses for ranges.
///
/// Getting them wrong silently returns the wrong window, so apps build these queries only here.
abstract final class ApiQuery {
  /// GET /v1/appointments. Server: starts_at >= from AND starts_at <= to (UTC 'Y-m-d H:i:s').
  /// from = local 00:00 of [from] in UTC; to = local 00:00 of ([to] + 1 day) in UTC minus 1 second.
  static Map<String, Object?> appointments({
    required LocalDate from,
    required LocalDate to,
    String? timezone,
    int? staffId,
    AppointmentStatus? status,
  }) {
    final start = Dates.startOfLocalDayUtc(from, timezone);
    final end = Dates.startOfLocalDayUtc(to.addDays(1), timezone).subtract(const Duration(seconds: 1));
    return {
      'from': Dates.formatApiUtc(start),
      'to': Dates.formatApiUtc(end),
      'staff': ?staffId,
      if (status != null) 'status': status.wire,
    };
  }

  /// GET /v1/orders. Server: created_at >= from AND created_at < to (unix seconds).
  static Map<String, Object?> orders({
    required LocalDate from,
    required LocalDate to,
    String? timezone,
    OrderStatus? status,
    int? limit,
  }) =>
      {
        'from': Dates.toUnix(Dates.startOfLocalDayUtc(from, timezone)),
        'to': Dates.toUnix(Dates.startOfLocalDayUtc(to.addDays(1), timezone)),
        if (status != null) 'status': status.wire,
        'limit': ?limit,
      };

  /// analytics/overview, payroll, finance/summary, finance/transactions: plain 'YYYY-MM-DD'
  /// (server treats them as UTC days; documented limitation).
  static Map<String, Object?> utcDays({required LocalDate from, required LocalDate to}) =>
      {'from': from.toIso(), 'to': to.toIso()};

  /// /v1/me/appointments, /v1/me/stats, /v1/me/schedule, /v1/site/{slug}/booked-days:
  /// business-local dates.
  static Map<String, Object?> localDays({LocalDate? from, LocalDate? to}) => {
        if (from != null) 'from': from.toIso(),
        if (to != null) 'to': to.toIso(),
      };

  /// GET /v1/staff/{id}/availability.
  static Map<String, Object?> availability({required LocalDate date, required int serviceId}) =>
      {'date': date.toIso(), 'service_id': serviceId};

  /// page/per_page helper; per_page is clamped by the server (directory/consumer 1..50, crm 1..100).
  static Map<String, Object?> page(int page, {int perPage = 20}) => {'page': page, 'per_page': perPage};
}
