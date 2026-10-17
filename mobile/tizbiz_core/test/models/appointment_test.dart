import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('business shape (me/appointments)', () {
    final a = Appointment.fromJson(dataList(meAppointmentsJson).single);
    expect(a.id, 5012);
    expect(a.startsAt, DateTime.utc(2026, 10, 17, 5));
    expect(a.endsAt, DateTime.utc(2026, 10, 17, 5, 40));
    expect(a.duration, const Duration(minutes: 40));
    expect(a.status, AppointmentStatus.confirmed);
    expect(a.paid, isTrue);
    expect(a.requiresDeposit, isFalse);
    expect(a.staffName, 'Usta Jahongir');
    expect(a.serviceDuration, 40);
    expect(a.business, isNull);
    expect(a.servicePriceTiyin, isNull);
    expect(a.startLocal().hhmm, '10:00');
    expect(a.endLocal().hhmm, '10:40');
    expect(a.items, isEmpty);
    expect(a.createdAt, Dates.fromUnix(1792054800));
    final json = a.toJson();
    expect(json.containsKey('service'), isFalse);
    expect(json.containsKey('staff'), isFalse);
    expect(json['starts_at'], '2026-10-17 05:00:00');
    expectFixedPoint(a, (x) => x.toJson(), Appointment.fromJson);
  });

  test('consumer shape (nested)', () {
    final a = Appointment.fromJson(dataList(consumerAppointmentsJson).single);
    expect(a.staffId, 2);
    expect(a.serviceId, 11);
    expect(a.businessId, 2);
    expect(a.serviceName, 'Soch olish + soqol');
    expect(a.serviceDuration, 40);
    expect(a.servicePriceTiyin, 8000000);
    expect(a.staffName, 'Usta Jahongir');
    expect(a.business?.slug, 'shox-barber');
    expect(a.business?.engine, Engine.slot);
    expect(a.canCancel, isFalse);
    expect(a.canReview, isFalse);
    expect(a.reviewId, isNull);
    expect(a.startLocal().date, const LocalDate(2026, 10, 18));
    final json = a.toJson();
    expect(json['service'], {'id': 11, 'name': 'Soch olish + soqol', 'duration_min': 40, 'price_tiyin': 8000000});
    expect(json['staff'], {'id': 2, 'name': 'Usta Jahongir'});
    expectFixedPoint(a, (x) => x.toJson(), Appointment.fromJson);

    final changed = a.copyWith(status: AppointmentStatus.canceled, canCancel: false, reviewId: 9);
    expect(changed.status, AppointmentStatus.canceled);
    expect(changed.reviewId, 9);
    expect(changed.copyWith(reviewId: null).reviewId, isNull);
    expect(changed.copyWith().reviewId, 9);
  });

  test('unpaid deposit, missing items', () {
    final a = Appointment.fromJson(dataMap(appointmentUnpaidJson));
    expect(a.paid, isFalse);
    expect(a.depositTiyin, 2000000);
    expect(a.requiresDeposit, isTrue);
    expect(a.items, isEmpty);
    expect(a.status, AppointmentStatus.pending);
    expect(a.copyWith(paid: true).requiresDeposit, isFalse);
    expectFixedPoint(a, (x) => x.toJson(), Appointment.fromJson);
  });

  test('missing starts_at -> epoch, items parsed', () {
    final a = Appointment.fromJson(const {
      'id': 1,
      'items': [
        {'id': 3, 'kind': 'product', 'name': 'Shampun', 'qty': '2', 'price_tiyin': '1500000'},
      ],
    });
    expect(a.startsAt, DateTime.utc(1970));
    expect(a.status, AppointmentStatus.unknown);
    expect(a.items.single.totalTiyin, 3000000);
    expect(a.items.single.kind, 'product');
    expectFixedPoint(a, (x) => x.toJson(), Appointment.fromJson);
  });
}
