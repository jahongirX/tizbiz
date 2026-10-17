import 'package:bizcat/features/booking_catalog/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fake_api.dart';
import '../../support/fixtures.dart';
import '../../support/pump.dart';

const _slug = 'aziza-tortlari';
final _uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void _catalogApi(FakeApi api) {
  api
    ..on('GET', '/v1/site/$_slug', body: Fx.siteCatalog)
    ..on('GET', '/v1/consumer/orders/702', body: Fx.order702)
    ..on('GET', '/v1/consumer/orders/690', body: Fx.order690);
}

Future<void> _addTwice(WidgetTester t) async {
  await t.tap(find.text("Qo'shish"));
  await settle(t);
  await t.tap(find.byTooltip("Ko'paytirish"));
  await settle(t);
}

void main() {
  testWidgets('menu: add twice -> the cart bar shows the count and total', (t) async {
    final h = await pumpBizcat(t, location: '/b/$_slug/menu', setup: _catalogApi);
    await settle(t);
    expect(find.text('Aziza Tortlari'), findsOneWidget);
    expect(find.text('Tortlar'), findsWidgets);
    expect(find.text('Napoleon torti (1 kg)'), findsOneWidget);

    await _addTwice(t);
    expect(find.text('Savat · 2 ta'), findsOneWidget);
    expect(find.text(Money.format(45000000)), findsOneWidget);
    expect(h.container.read(cartProvider(_slug)).toOrderLines().single.qty, 2);

    await t.tap(find.text("Savatni ko'rish"));
    await settle(t);
    expect(h.location, '/b/$_slug/cart');
    expect(find.text('Savat'), findsOneWidget);
    expect(find.text("Yetkazib berish yo'q: buyurtmani joyida olasiz."), findsOneWidget);
  });

  testWidgets('cart -> checkout (signed in) posts the order and opens it', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/$_slug/menu',
      signedIn: true,
      setup: (api) {
        _catalogApi(api);
        api.on('POST', '/v1/consumer/orders', status: 201, body: Fx.order702);
      },
    );
    await settle(t);
    await _addTwice(t);
    await t.tap(find.text("Savatni ko'rish"));
    await settle(t);
    await t.tap(find.text('Rasmiylashtirish'));
    await settle(t);
    expect(h.location, '/b/$_slug/checkout');
    expect(find.text('Napoleon torti (1 kg) ×2'), findsOneWidget);

    await t.tap(find.text('Buyurtma berish'));
    await settle(t);

    final req = h.api.last('POST', '/v1/consumer/orders');
    expect(req.body, {
      'slug': _slug,
      'items': [
        {'service_id': 61, 'qty': 2},
      ],
      'name': 'Aziza Karimova',
    });
    expect(req.headers['idempotency-key'], matches(_uuidV4));
    expect(h.location, '/bookings/o/702?new=1');
    expect(h.container.read(cartProvider(_slug)).isEmpty, isTrue);
  });

  testWidgets('a 403 on checkout shows the message and a call button', (t) async {
    final h = await pumpBizcat(
      t,
      location: '/b/$_slug/menu',
      signedIn: true,
      setup: (api) {
        _catalogApi(api);
        api.on(
          'POST',
          '/v1/consumer/orders',
          status: 403,
          body: Fx.error(403, 'Bu biznes hozir onlayn buyurtma qabul qilmaydi.'),
        );
      },
    );
    await settle(t);
    await _addTwice(t);
    await t.tap(find.text("Savatni ko'rish"));
    await settle(t);
    await t.tap(find.text('Rasmiylashtirish'));
    await settle(t);
    await t.tap(find.text('Buyurtma berish'));
    await settle(t);

    final message = find.text('Bu biznes hozir onlayn buyurtma qabul qilmaydi.');
    await t.scrollUntilVisible(message, 200, scrollable: find.byType(Scrollable).first);
    expect(message, findsOneWidget);
    expect(find.text("Qo'ng'iroq qilish"), findsOneWidget);
    expect(h.location, '/b/$_slug/checkout');
    expect(h.container.read(cartProvider(_slug)).count, 2);
  });

  testWidgets('signed out, Rasmiylashtirish goes to login with from', (t) async {
    final h = await pumpBizcat(t, location: '/b/$_slug/menu', setup: _catalogApi);
    await settle(t);
    await _addTwice(t);
    await t.tap(find.text("Savatni ko'rish"));
    await settle(t);
    await t.tap(find.text('Rasmiylashtirish'));
    await settle(t);
    expect(h.location, '/login?from=%2Fb%2Faziza-tortlari%2Fcheckout');
  });

  testWidgets('reorder prefills the cart', (t) async {
    final h = await pumpBizcat(t, location: '/b/$_slug/menu?reorder=702', signedIn: true, setup: _catalogApi);
    await settle(t);
    final cart = h.container.read(cartProvider(_slug));
    expect(cart.count, 2);
    expect(cart.lines.keys.single, 61);
    expect(find.text('Savat · 2 ta'), findsOneWidget);
  });

  testWidgets('empty cart screen offers the way back to the menu', (t) async {
    await pumpBizcat(t, location: '/b/$_slug/cart', setup: _catalogApi);
    await settle(t);
    expect(find.text("Savat bo'sh"), findsOneWidget);
    expect(find.text('Menyuga qaytish'), findsOneWidget);
  });

  test('applyReorder skips items that are gone', () async {
    final store = StorefrontData.fromJson(Fx.data(Fx.siteCatalog));
    final order = Order.fromJson({
      ...Fx.order702,
      'items': [
        {'id': 1, 'service_id': 61, 'name': 'Napoleon torti (1 kg)', 'price_tiyin': 22500000, 'qty': 1},
        {'id': 2, 'service_id': 999, 'name': 'Eski tort', 'price_tiyin': 100, 'qty': 1},
      ],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctl = container.read(cartProvider(_slug).notifier);
    expect(await ctl.applyReorder(order, store), 1);
    final cart = container.read(cartProvider(_slug));
    expect(cart.count, 1);
    expect(cart.totalTiyin, 22500000);
    ctl.setQty(61, 120);
    expect(container.read(cartProvider(_slug)).qtyOf(61), kMaxLineQty);
    ctl.setQty(61, 0);
    expect(container.read(cartProvider(_slug)).isEmpty, isTrue);
  });
}
