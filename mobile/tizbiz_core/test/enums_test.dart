import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  group('AppointmentStatus', () {
    test('fromWire', () {
      expect(AppointmentStatus.fromWire('no_show'), AppointmentStatus.noShow);
      expect(AppointmentStatus.fromWire('cancelled'), AppointmentStatus.unknown);
      expect(AppointmentStatus.fromWire('canceled'), AppointmentStatus.canceled);
      expect(AppointmentStatus.fromWire(null), AppointmentStatus.unknown);
      expect(AppointmentStatus.canceled.isTerminal, isTrue);
      expect(AppointmentStatus.arrived.isLive, isTrue);
      expect(AppointmentStatus.unknown.wire, 'unknown');
    });

    test('transitions', () {
      expect(AppointmentStatus.pending.adminNext, [
        AppointmentStatus.confirmed,
        AppointmentStatus.arrived,
        AppointmentStatus.completed,
        AppointmentStatus.noShow,
        AppointmentStatus.canceled,
      ]);
      expect(AppointmentStatus.confirmed.staffNext,
          [AppointmentStatus.arrived, AppointmentStatus.completed, AppointmentStatus.noShow]);
      expect(AppointmentStatus.arrived.staffNext, [AppointmentStatus.completed, AppointmentStatus.noShow]);
      expect(AppointmentStatus.completed.adminNext, isEmpty);
      expect(AppointmentStatus.canceled.staffNext, isEmpty);
    });
  });

  test('OrderStatus', () {
    expect(OrderStatus.fromWire('new'), OrderStatus.newOrder);
    expect(OrderStatus.fromWire('canceled'), OrderStatus.unknown);
    expect(OrderStatus.fromWire('cancelled'), OrderStatus.cancelled);
    expect(OrderStatus.newOrder.next, OrderStatus.confirmed);
    expect(OrderStatus.ready.next, OrderStatus.delivered);
    expect(OrderStatus.delivered.next, isNull);
    expect(OrderStatus.board.length, 6);
    expect(OrderStatus.ready.isActive, isTrue);
    expect(OrderStatus.delivered.isActive, isFalse);
  });

  test('Engine', () {
    expect(Engine.fromWire(null), Engine.slot);
    expect(Engine.fromWire('xyz'), Engine.slot);
    expect(Engine.fromWire('rental'), Engine.rental);
    expect(Engine.medical.isCatalogStorefront, isTrue);
    expect(Engine.slot.isCatalogStorefront, isFalse);
    expect(Engine.catalog.hasTimetable, isFalse);
    expect(Engine.medical.hasTimetable, isTrue);
    expect(Engine.rental.isRental, isTrue);
    expect(Engine.catalog.servicesTerm, 'Menyu');
    expect(Engine.medical.staffTerm, 'Shifokorlar');
    expect(Engine.rental.appointmentsTerm, 'Ijaralar');
  });

  test('BizRole and small enums', () {
    expect(BizRole.fromWire('business_admin').isManager, isTrue);
    expect(BizRole.fromWire('staff').isManager, isFalse);
    expect(BizRole.fromWire('x'), BizRole.unknown);
    expect(RentalSession.fromWire(null), isNull);
    expect(RentalSession.fromWire('evening'), RentalSession.evening);
    expect(Gender.fromWire('female'), Gender.female);
    expect(Gender.fromWire('x'), isNull);
    expect(ReviewStatus.fromWire('x'), ReviewStatus.published);
    expect(ReviewStatus.fromWire('hidden'), ReviewStatus.hidden);
    expect(PaymentProvider.fromWire('payme'), PaymentProvider.payme);
    expect(PaymentProvider.fromWire('click'), isNull);
  });
}
