import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/auth/business_picker_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  final two = [fxMembership(), fxMembership(engine: Engine.catalog)];

  testWidgets('lists businesses, tapping the inactive one switches', (t) async {
    final s = await pumpScreen(t, const BusinessPickerScreen(), session: fxSignedIn(businesses: two, needsPicker: true));
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Aziza Tortlari'), findsOneWidget);
    expect(find.text('Faol'), findsOneWidget);
    await t.tap(find.text('Aziza Tortlari'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(s.switchCalls, [3]);
  });

  testWidgets('tapping the active one completes the picker; 403 shows a snack', (t) async {
    final s = await pumpScreen(t, const BusinessPickerScreen(), session: fxSignedIn(businesses: two, needsPicker: true));
    await t.tap(find.text('Shox Barber'));
    await t.pump();
    expect(s.completePickerCount, 1);

    s.switchError = const ApiException(kind: ApiErrorKind.http, status: 403, detail: "Bu biznesga kirish yo'q.");
    await t.tap(find.text('Aziza Tortlari'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text("Bu biznesga kirish yo'q."), findsOneWidget);
  });

  testWidgets('Chiqish logs out', (t) async {
    final s = await pumpScreen(t, const BusinessPickerScreen(), session: fxSignedIn(businesses: two, needsPicker: true));
    await t.tap(find.text('Chiqish'));
    await t.pump();
    expect(s.logoutCount, 1);
  });
}
