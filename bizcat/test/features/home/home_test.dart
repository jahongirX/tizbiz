import 'package:bizcat/features/home/home_widgets.dart';
import 'package:bizcat/features/home/providers.dart';
import 'package:bizcat/shared/widgets/category_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(420, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('signed out: categories and featured render, no revisit; category tap opens explore', (t) async {
    _tall(t);
    final h = await pumpBizcat(t);
    expect(find.text('Xush kelibsiz!'), findsOneWidget);
    expect(find.text('Kategoriyalar'), findsOneWidget);
    // A horizontal row: the first cards are on screen, the rest scroll in.
    expect(find.byType(CategoryTile), findsWidgets);
    expect(find.text('Tavsiya etilgan'), findsOneWidget);
    expect(find.text('Shox Barber'), findsWidgets);
    expect(find.text('Siz borgan joylar'), findsNothing);
    expect(h.api.called('GET', '/v1/consumer/appointments'), isFalse);

    await t.tap(find.descendant(of: find.byType(CategoryTile), matching: find.text('Barber')));
    await settle(t);
    expect(h.location, '/explore?category=barber');
  });

  testWidgets('signed in: next booking card and the revisit rebook button', (t) async {
    _tall(t);
    final h = await pumpBizcat(
      t,
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/appointments', body: Fx.appointmentsUpcoming, when: (q) => q['scope'] == 'upcoming')
        ..on('GET', '/v1/consumer/appointments', body: Fx.appointmentsPast, when: (q) => q['scope'] == 'past')
        ..on('GET', '/v1/consumer/orders', body: Fx.ordersPast),
    );
    expect(find.text('Salom, Aziza!'), findsOneWidget);
    expect(find.descendant(of: find.byType(NextBookingCard), matching: find.text('Shox Barber')), findsOneWidget);
    expect(h.api.last('GET', '/v1/consumer/appointments').query['per_page'], isNotNull);

    final button = find.descendant(of: find.byType(RevisitCard), matching: find.text('Qayta yozilish'));
    await t.ensureVisible(button.first);
    await t.pump();
    await t.tap(button.first);
    await settle(t);
    expect(h.location, '/b/shox-barber/book?service=11&staff=2');
  });

  testWidgets('no businesses in the city -> empty state that clears the city', (t) async {
    final h = await pumpBizcat(
      t,
      prefs: {'bizcat.city': 'Termiz'},
      setup: (api) => api.on('GET', '/v1/directory/businesses', body: Fx.emptyPage),
    );
    expect(find.text("Bu shaharda hali bizneslar yo'q"), findsOneWidget);
    expect(h.api.last('GET', '/v1/directory/businesses').query['city'], 'Termiz');
    await t.tap(find.text("Barcha shaharlarda ko'rish"));
    await settle(t);
    expect(h.prefs.getString('bizcat.city'), isNull);
  });

  test('buildRevisitItems keeps completed/delivered, newest per business', () {
    final past = Fx.items(Fx.appointmentsPast).map(Appointment.fromJson).toList();
    final orders = Fx.items(Fx.ordersPast).map(Order.fromJson).toList();
    final items = buildRevisitItems(past, orders);
    expect(items, isNotEmpty);
    expect(items.map((i) => i.business.id).toSet().length, items.length);
    for (var i = 1; i < items.length; i++) {
      expect(items[i - 1].lastAt.isAfter(items[i].lastAt) || items[i - 1].lastAt == items[i].lastAt, isTrue);
    }
    final shox = items.firstWhere((i) => i.business.slug == 'shox-barber');
    expect(shox.rebookPath(), '/b/shox-barber/book?service=11&staff=2');
  });
}
