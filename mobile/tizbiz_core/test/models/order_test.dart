import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('business order', () {
    final o = Order.fromJson(dataMap(businessOrderJson));
    expect(o.status, OrderStatus.delivered);
    expect(o.business, isNull);
    expect(o.canCancel, isNull);
    expect(o.items.single.totalTiyin, 22500000);
    expect(o.itemsCount, 1);
    expect(o.createdAt, Dates.fromUnix(1792054800));
    expectFixedPoint(o, (x) => x.toJson(), Order.fromJson);
  });

  test('consumer order', () {
    final o = Order.fromJson(dataList(consumerOrdersJson).single);
    expect(o.status, OrderStatus.newOrder);
    expect(o.itemsCount, 1);
    expect(o.items.single.qty, 2);
    expect(o.items.single.totalTiyin, 45000000);
    expect(o.canCancel, isTrue);
    expect(o.canReview, isFalse);
    expect(o.business?.slug, 'aziza-tortlari');
    expect(o.business?.engine, Engine.catalog);
    expectFixedPoint(o, (x) => x.toJson(), Order.fromJson);
    final c = o.copyWith(status: OrderStatus.cancelled, canCancel: false);
    expect(c.status, OrderStatus.cancelled);
    expect(c.canCancel, isFalse);
  });

  test('items_count falls back to items.length', () {
    final o = Order.fromJson(const {
      'id': 1,
      'status': 'ready',
      'items': [
        {'id': 1, 'name': 'a', 'price_tiyin': 1, 'qty': 1},
        {'id': 2, 'name': 'b', 'price_tiyin': 1, 'qty': 1},
      ],
    });
    expect(o.itemsCount, 2);
  });
}
