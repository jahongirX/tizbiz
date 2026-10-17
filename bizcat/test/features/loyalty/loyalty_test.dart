import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

void main() {
  testWidgets('shows the wallet entry and totals', (t) async {
    await pumpBizcat(
      t,
      location: '/profile/wallet',
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/consumer/loyalty', body: Fx.loyalty),
    );
    expect(find.text('Hamyon'), findsOneWidget);
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(Money.format(1500000)), findsNWidgets(2)); // total + entry
    expect(find.text('Jami ballar: 120'), findsOneWidget);
    expect(find.textContaining('Depozit balansi'), findsNothing);
  });

  testWidgets('an empty list shows the empty state', (t) async {
    await pumpBizcat(
      t,
      location: '/profile/wallet',
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/consumer/loyalty', body: Fx.emptyList),
    );
    expect(find.text("Hali bonuslar yo'q"), findsOneWidget);
  });
}
