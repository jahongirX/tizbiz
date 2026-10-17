import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('consumer slot booking = BP 4.6 body', () {
    final r = ConsumerBookingRequest.slot(
      staffId: 2,
      serviceId: 11,
      startsAt: DateTime.utc(2026, 10, 18, 5),
      notes: 'Soqolni qisqa qiling',
      name: 'Aziza',
    );
    expect(r.toJson(), {
      'staff_id': 2,
      'service_id': 11,
      'starts_at': '2026-10-18 05:00:00',
      'notes': 'Soqolni qisqa qiling',
      'name': 'Aziza',
    });
    expect(ConsumerBookingRequest.slot(staffId: 2, serviceId: 11, startsAt: DateTime.utc(2026, 10, 18, 5)).toJson().keys,
        ['staff_id', 'service_id', 'starts_at']);
  });

  test('consumer rental booking', () {
    const r = ConsumerBookingRequest.rental(
      staffId: 5,
      serviceId: 40,
      date: LocalDate(2026, 11, 14),
      session: RentalSession.evening,
      guests: 180,
    );
    expect(r.toJson(), {'staff_id': 5, 'service_id': 40, 'date': '2026-11-14', 'session': 'evening', 'guests': 180});
    const fullDay = ConsumerBookingRequest.rental(staffId: 5, serviceId: 40, date: LocalDate(2026, 11, 14));
    expect(fullDay.toJson().containsKey('session'), isFalse);
    expect(fullDay.isRental, isTrue);
  });

  test('admin booking', () {
    final r = AdminBookingRequest(
      staffId: 2,
      serviceId: 11,
      startsAt: DateTime.utc(2026, 10, 18, 5),
      clientPhone: '90 111 11 11',
      clientName: 'Ali',
      status: AppointmentStatus.confirmed,
    );
    final json = r.toJson();
    expect((json['client'] as Map<String, dynamic>)['phone'], '+998901111111');
    expect(json['client'], {'phone': '+998901111111', 'name': 'Ali'});
    expect(json['status'], 'confirmed');
    expect(json.containsKey('client_id'), isFalse);
    const byId = AdminBookingRequest(staffId: 5, serviceId: 40, date: LocalDate(2026, 11, 14), session: RentalSession.morning, clientId: 881);
    expect(byId.toJson(), {'staff_id': 5, 'service_id': 40, 'date': '2026-11-14', 'session': 'morning', 'client_id': 881});
    int? none() => null;
    expect(() => AdminBookingRequest(staffId: 1, serviceId: 1, clientId: none()), throwsA(isA<AssertionError>()));
  });

  test('consumer order', () {
    const r = ConsumerOrderRequest(
      slug: 'aziza-tortlari',
      items: [OrderLine(61, 2)],
      note: 'Soat 17:00 da olib ketaman',
      name: 'Aziza',
    );
    expect(r.toJson(), {
      'slug': 'aziza-tortlari',
      'items': [
        {'service_id': 61, 'qty': 2},
      ],
      'note': 'Soat 17:00 da olib ketaman',
      'name': 'Aziza',
    });
  });

  test('review input', () {
    int? none() => null;
    expect(() => ReviewInput(rating: 5, appointmentId: none()), throwsA(isA<AssertionError>()));
    expect(() => ReviewInput(appointmentId: 1, orderId: 2 + (none() ?? 0), rating: 5), throwsA(isA<AssertionError>()));
    expect(const ReviewInput(appointmentId: 4990, rating: 5, comment: 'Juda yoqdi!').toJson(),
        {'appointment_id': 4990, 'rating': 5, 'comment': 'Juda yoqdi!'});
    expect(const ReviewInput(orderId: 690, rating: 4).toJson(), {'order_id': 690, 'rating': 4});
    expect(const ReviewInput(orderId: 690, rating: 4).toPatchJson(), {'rating': 4, 'comment': null});
  });

  test('team member bodies', () {
    expect(const TeamMemberPatch(unlinkStaff: true).toJson(), {'staff_id': null});
    expect(const TeamMemberPatch(role: BizRole.staff).toJson(), {'role': 'staff'});
    expect(const TeamMemberPatch(role: BizRole.admin, staffId: 2).toJson(), {'role': 'business_admin', 'staff_id': 2});
    expect(
      const TeamMemberInput(phone: '93 111 00 01', name: 'Usta Jahongir', role: BizRole.staff, password: 'secret123', staffId: 2)
          .toJson(),
      {'phone': '+998931110001', 'name': 'Usta Jahongir', 'role': 'staff', 'password': 'secret123', 'staff_id': 2},
    );
  });

  test('profile patch / time-off', () {
    expect(const ConsumerProfilePatch(locale: 'ru').toJson(), {'locale': 'ru'});
    expect(
      const ConsumerProfilePatch(name: 'Aziza K.', birthday: LocalDate(1996, 4, 12), gender: Gender.female).toJson(),
      {'name': 'Aziza K.', 'birthday': '1996-04-12', 'gender': 'female'},
    );
    expect(const TimeOffInput(date: LocalDate(2026, 10, 25), reason: 'Dam olish').toJson(),
        {'date': '2026-10-25', 'reason': 'Dam olish'});
    expect(
      const TimeOffInput(date: LocalDate(2026, 10, 25), start: HmTime(13, 0), end: HmTime(14, 0)).toJson(),
      {'date': '2026-10-25', 'start_time': '13:00:00', 'end_time': '14:00:00'},
    );
  });
}
