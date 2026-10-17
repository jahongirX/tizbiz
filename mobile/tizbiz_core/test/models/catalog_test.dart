import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('live service row', () {
    final s = Service.fromJson(dataList(servicesLiveJson).single);
    expect(s.isActive, isTrue);
    expect(s.onlineBookable, isTrue);
    expect(s.gallery, isEmpty);
    expect(s.depositTiyin, 1000000);
    expect(s.requiresDeposit, isTrue);
    expect(s.durationMin, 40);
    expect(s.categoryId, 5);
    expect(s.createdAt, Dates.fromUnix(1784364000));
    expect(s.toInput().keys.toSet(), {
      'name', 'category_id', 'duration_min', 'price_tiyin', 'deposit_tiyin', //
      'is_active', 'online_bookable', 'image', 'description', 'gallery',
    });
    expect(s.toInput()['is_active'], isTrue);
    expectFixedPoint(s, (x) => x.toJson(), Service.fromJson);
  });

  test('service defaults when keys are missing', () {
    final s = Service.fromJson(const {'id': 1, 'name': 'X'});
    expect(s.durationMin, 30);
    expect(s.requiresDeposit, isFalse);
    expect(s.gallery, isEmpty);
  });

  test('service category', () {
    final c = ServiceCategory.fromJson(dataList(serviceCategoriesLiveJson).single);
    expect(c.name, 'Soch');
    expect(c.toInput(), {'name': 'Soch', 'sort': 1, 'image': null});
    expectFixedPoint(c, (x) => x.toJson(), ServiceCategory.fromJson);
  });

  test('live staff row (is_active 1)', () {
    final s = Staff.fromJson(dataList(staffListLiveJson).single);
    expect(s.isActive, isTrue);
    expect(s.userId, 31);
    expect(s.commissionPercent, 40);
    expect(s.toInput(), {'name': 'Usta Jahongir', 'specialization': 'Sartarosh', 'is_active': true, 'commission_percent': 40});
    expectFixedPoint(s, (x) => x.toJson(), Staff.fromJson);
  });

  test('public staff shape', () {
    final s = Staff.fromJson(const {'id': 2, 'name': 'Usta Jahongir', 'specialization': 'Sartarosh'});
    expect(s.isActive, isTrue);
    expect(s.userId, isNull);
    expect(s.business, isNull);
    expectFixedPoint(s, (x) => x.toJson(), Staff.fromJson);
  });

  test('me/staff with business', () {
    final s = Staff.fromJson(dataMap(meStaffJson));
    expect(s.business?.timezone, 'Asia/Tashkent');
    expect(s.business?.engine, Engine.slot);
    expect(s.business?.logo, isNull);
    expect(s.commissionPercent, 40);
    expectFixedPoint(s, (x) => x.toJson(), Staff.fromJson);
  });
}
