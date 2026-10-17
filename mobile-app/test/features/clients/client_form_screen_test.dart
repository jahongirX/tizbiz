import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/clients/client_form_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('empty name and bad phone show errors and send nothing', (t) async {
    final http = FakeHttp();
    await pumpScreen(t, const ClientFormScreen(), http: http);
    await t.enterText(find.widgetWithText(TextFormField, 'Telefon'), '90123');
    await t.enterText(find.widgetWithText(TextFormField, 'Email'), 'nope');
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    expect(find.text('Ismni kiriting'), findsOneWidget);
    expect(find.text("Telefon raqam noto'g'ri"), findsOneWidget);
    expect(find.text("Email noto'g'ri"), findsOneWidget);
    expect(http.requests, isEmpty);
  });

  testWidgets('create sends the toInput body; 422 phone shows on the field', (t) async {
    const dup = 'Bu telefon raqam ushbu biznesda allaqachon mavjud.';
    final http = FakeHttp()..on('POST', Endpoints.clients, status: 422, body: apiError(422, dup, pointer: 'phone'));
    await pumpScreen(t, const ClientFormScreen(), http: http);
    await t.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Ali Valiyev');
    await t.enterText(find.widgetWithText(TextFormField, 'Telefon'), '901234567');
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    expect(http.calls(Endpoints.clients, method: 'POST').single.body, {
      'name': 'Ali Valiyev',
      'phone': '+998901234567',
      'email': null,
      'birthday': null,
      'notes': null,
      'tags': <String>[],
    });
    expect(find.text(dup), findsOneWidget);
  });

  test('birthday cannot be in the future', () {
    const today = LocalDate(2026, 10, 17);
    expect(validateBirthday(const LocalDate(2026, 10, 18), today), isNotNull);
    expect(validateBirthday(today, today), isNull);
    expect(validateBirthday(null, today), isNull);
  });

  test('name and email validators', () {
    expect(validateClientName('  '), 'Ismni kiriting');
    expect(validateClientName('x' * 129), isNotNull);
    expect(validateClientEmail(''), isNull);
    expect(validateClientEmail('a@b.uz'), isNull);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
