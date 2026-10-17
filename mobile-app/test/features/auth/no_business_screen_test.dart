import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/auth/no_business_screen.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('shows the text and the buttons call the session', (t) async {
    final s = await pumpScreen(t, const NoBusinessScreen(),
        session: fxSignedIn(businesses: const [], activeBusinessId: null));
    expect(find.text("Siz hech qaysi faol biznes a'zosi emassiz"), findsOneWidget);
    expect(find.text("Biznes egasi sizni Jamoa bo'limiga qo'shishi kerak."), findsOneWidget);
    await t.tap(find.text('Qayta tekshirish'));
    await t.pump();
    expect(s.refreshMeCount, 1);
    await t.tap(find.text('Chiqish'));
    await t.pump();
    expect(s.logoutCount, 1);
  });
}
