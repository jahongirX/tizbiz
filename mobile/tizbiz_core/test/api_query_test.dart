import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  const day = LocalDate(2026, 10, 17);

  test('appointments: UTC datetimes of the local day', () {
    expect(ApiQuery.appointments(from: day, to: day), {'from': '2026-10-16 19:00:00', 'to': '2026-10-17 18:59:59'});
    expect(
      ApiQuery.appointments(from: day, to: day, staffId: 2, status: AppointmentStatus.confirmed),
      {'from': '2026-10-16 19:00:00', 'to': '2026-10-17 18:59:59', 'staff': 2, 'status': 'confirmed'},
    );
    expect(ApiQuery.appointments(from: day, to: day).containsKey('staff'), isFalse);
    expect(ApiQuery.appointments(from: day, to: day).containsKey('status'), isFalse);
  });

  test('orders: unix seconds, exclusive end', () {
    final q = ApiQuery.orders(from: day, to: day);
    expect(q['from'], 1792177200);
    expect(q['to'], 1792263600);
    expect(Dates.fromUnix(q['from']), DateTime.utc(2026, 10, 16, 19));
    expect(q.keys, ['from', 'to']);
    expect(ApiQuery.orders(from: day, to: day, status: OrderStatus.newOrder, limit: 50)['status'], 'new');
  });

  test('utcDays / localDays', () {
    const from = LocalDate(2026, 10, 1);
    expect(ApiQuery.utcDays(from: from, to: day), {'from': '2026-10-01', 'to': '2026-10-17'});
    expect(ApiQuery.localDays(from: from, to: day), {'from': '2026-10-01', 'to': '2026-10-17'});
    expect(ApiQuery.localDays(), isEmpty);
    expect(ApiQuery.localDays(from: from), {'from': '2026-10-01'});
  });

  test('availability / page', () {
    expect(ApiQuery.availability(date: const LocalDate(2026, 10, 19), serviceId: 2), {'date': '2026-10-19', 'service_id': 2});
    expect(ApiQuery.page(2, perPage: 50), {'page': 2, 'per_page': 50});
    expect(ApiQuery.page(1), {'page': 1, 'per_page': 20});
  });
}
