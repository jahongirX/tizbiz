import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/features/auth/login_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  const signedOut = SessionSignedOut();

  testWidgets('empty submit shows both errors and does not log in', (t) async {
    final s = await pumpScreen(t, const LoginScreen(), session: signedOut);
    await t.tap(find.widgetWithText(FilledButton, 'Kirish'));
    await t.pump();
    expect(find.text("Telefon raqam noto'g'ri"), findsOneWidget);
    expect(find.text('Parolni kiriting'), findsOneWidget);
    expect(s.loginCalls, isEmpty);
  });

  testWidgets('valid submit calls login with the normalized phone', (t) async {
    final s = await pumpScreen(t, const LoginScreen(), session: signedOut);
    await t.enterText(find.byType(TextFormField).at(0), '901111111');
    await t.enterText(find.byType(TextFormField).at(1), 'secret123');
    expect(find.text('90 111 11 11'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Kirish'));
    await t.pump();
    expect(s.loginCalls.single, (phone: '+998901111111', password: 'secret123'));
  });

  testWidgets('a 401 shows the server detail under the form', (t) async {
    final s = await pumpScreen(t, const LoginScreen(), session: signedOut);
    s.loginError = const ApiException(kind: ApiErrorKind.http, status: 401, detail: "Telefon yoki parol noto'g'ri.");
    await t.enterText(find.byType(TextFormField).at(0), '901111111');
    await t.enterText(find.byType(TextFormField).at(1), 'wrong');
    await t.tap(find.widgetWithText(FilledButton, 'Kirish'));
    await t.pump();
    expect(find.text("Telefon yoki parol noto'g'ri."), findsOneWidget);
  });

  testWidgets('signed-out message banner and demo chip login', (t) async {
    final s = await pumpScreen(t, const LoginScreen(), session: const SessionSignedOut(message: kSessionExpiredMessage));
    expect(find.text(kSessionExpiredMessage), findsOneWidget);
    await t.ensureVisible(find.text('Usta (xodim)'));
    await t.pump();
    await t.tap(find.text('Usta (xodim)'));
    await t.pump();
    expect(s.loginCalls.single, (phone: '+998931110001', password: 'secret123'));
  });
}
