import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('slot payload', () {
    final s = StorefrontData.fromJson(dataMap(siteSlotJson));
    expect(s.engine, Engine.slot);
    expect(s.business.slug, 'shox-barber');
    expect(s.business.onlineBookingEnabled, isTrue);
    expect(s.business.timezone, 'Asia/Tashkent');
    expect(s.services.single.requiresDeposit, isTrue);
    expect(s.staff.single.name, 'Usta Jahongir');
    expect(s.staff.single.isActive, isTrue);
    expect(s.categories, isEmpty);
    expect(s.items, isEmpty);
    expectFixedPoint(s, (x) => x.toJson(), StorefrontData.fromJson);
  });

  test('catalog payload', () {
    final s = StorefrontData.fromJson(dataMap(siteCatalogJson));
    expect(s.engine, Engine.catalog);
    expect(s.engine.isCatalogStorefront, isTrue);
    expect(s.categories.first.id, 0);
    expect(s.categories.first.name, 'Boshqa');
    expect(s.categories.first.items.single.name, 'Napoleon torti (1 kg)');
    expect(s.staff, isEmpty);
    expect(s.services, isEmpty);
    expect(s.items.single.onlineBookable, isFalse);
    expect(s.items.single.gallery, ['https://api.tizbiz.uz/uploads/202609/n2.jpg']);
    expect(s.business.onlineBookingEnabled, isTrue);
    expectFixedPoint(s, (x) => x.toJson(), StorefrontData.fromJson);
  });

  test('legacy payload without engine', () {
    final s = StorefrontData.fromJson(dataMap(siteLegacyJson));
    expect(s.engine, Engine.slot);
    expect(s.business.logo, isNull);
    expect(s.business.address, isNull);
    expect(s.business.onlineBookingEnabled, isTrue);
    expectFixedPoint(s, (x) => x.toJson(), StorefrontData.fromJson);
  });

  test('availability', () {
    final a = Availability.fromJson(dataMap(availabilityJson));
    expect(a.date, const LocalDate(2026, 10, 19));
    expect(a.timezone, 'Asia/Tashkent');
    expect(a.slots, hasLength(3));
    expect(a.slots.first.startUtc, DateTime.utc(2026, 10, 19, 4));
    expect(a.slots.first.startLocal, const HmTime(9, 0));
    expect(a.slots.first.bucket, 'morning');
    expect(a.slots[1].bucket, 'afternoon');
    expect(a.slots[2].bucket, 'evening');
    expect(Dates.formatApiUtc(a.slots.first.startUtc), '2026-10-19 04:00:00');
    expectFixedPoint(a, (x) => x.toJson(), Availability.fromJson);
  });

  test('booked days', () {
    final b = BookedDays.fromJson(dataMap(bookedDaysJson));
    expect(b.isFullyBooked(const LocalDate(2026, 11, 14)), isTrue);
    expect(b.isFullyBooked(const LocalDate(2026, 11, 15)), isFalse);
    expect(b.isTaken(const LocalDate(2026, 11, 15), RentalSession.morning), isFalse);
    expect(b.isTaken(const LocalDate(2026, 11, 15), RentalSession.evening), isTrue);
    expect(b.isTaken(const LocalDate(2026, 11, 15), null), isTrue);
    expect(b.isTaken(const LocalDate(2026, 11, 16), null), isFalse);
    expect(b.toJson(), {
      'booked': {
        '2026-11-14': ['morning', 'evening'],
        '2026-11-15': ['evening'],
      },
    });
    expectFixedPoint(b, (x) => x.toJson(), BookedDays.fromJson);

    final empty = BookedDays.fromJson(dataMap(bookedDaysEmptyJson));
    expect(empty.booked, isEmpty);
    expect(BookedDays.fromJson(const {'booked': <String, dynamic>{}}).booked, isEmpty);
  });
}
