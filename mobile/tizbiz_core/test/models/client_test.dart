import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('list row with JSON-string tags', () {
    final c = Client.fromJson(dataList(clientsListJson).single);
    expect(c.tags, ['vip']);
    expect(c.lastVisit, DateTime.utc(2026, 10, 1, 6));
    expect(c.birthday, const LocalDate(1996, 4, 12));
    expect(c.visits, 5);
    expect(c.spentTiyin, 40000000);
    expect(c.categories.single.color, '#F59E0B');
    expect(c.email, isNull);
    expectFixedPoint(c, (x) => x.toJson(), Client.fromJson);
    expect(c.toInput(), {
      'name': 'Aziza Karimova',
      'phone': '+998900000001',
      'email': null,
      'birthday': '1996-04-12',
      'notes': null,
      'tags': ['vip'],
    });
  });

  test('toInput normalizes the phone', () {
    const c = Client(id: 0, name: 'Ali', phone: '90 111 11 11');
    expect(c.toInput()['phone'], '+998901111111');
  });

  test('detail without loyalty', () {
    final d = ClientDetail.fromJson(dataMap(clientDetailJson));
    expect(d.client.businessId, 2);
    expect(d.client.notes, 'Soqolni qisqa yoqtiradi');
    expect(d.client.tags, ['vip']);
    expect(d.loyalty, isNull);
    expect(d.history.single.status, AppointmentStatus.completed);
    expect(d.history.single.paid, isFalse);
    expect(d.categories.single.name, 'VIP');
    expectFixedPoint(d, (x) => x.toJson(), ClientDetail.fromJson);
  });

  test('detail with loyalty and categories index', () {
    final d = ClientDetail.fromJson({
      ...dataMap(clientDetailJson),
      'loyalty': {'points': 120, 'cashback_tiyin': 1500000},
    });
    expect(d.loyalty?.points, 120);
    expect(d.loyalty?.cashbackTiyin, 1500000);
    expectFixedPoint(d, (x) => x.toJson(), ClientDetail.fromJson);
    final cat = ClientCategory.fromJson(dataList(clientCategoriesJson).single);
    expect(cat.sort, 1);
    expectFixedPoint(cat, (x) => x.toJson(), ClientCategory.fromJson);
  });
}
