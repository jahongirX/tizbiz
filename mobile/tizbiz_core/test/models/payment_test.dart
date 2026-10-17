import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('deposit checkout', () {
    final d = DepositCheckout.fromJson(dataMap(depositJson));
    expect(d.checkoutUrl?.host, 'checkout.paycom.uz');
    expect(d.transaction.amountTiyin, 2000000);
    expect(d.transaction.id, 301);
    expect(d.transaction.appointmentId, 5012);
    expect(d.transaction.status, 'created');
    expect(d.provider, 'payme');
    expectFixedPoint(d, (x) => x.toJson(), DepositCheckout.fromJson);
    expect(PaymentProvider.fromWire(d.provider), PaymentProvider.payme);
  });
}
