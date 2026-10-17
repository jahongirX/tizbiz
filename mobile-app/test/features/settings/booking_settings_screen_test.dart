import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/settings/booking_settings_screen.dart';
import 'package:tizbiz_biznes/features/settings/widgets/booking_section.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Finder get _list => find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: _list);
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
}

FakeHttp _http() => FakeHttp()..on('GET', Endpoints.bookingSettings, body: envelope(jSettings()));

void main() {
  test('slug validation', () {
    expect(validateSlug('shox-barber'), isNull);
    expect(validateSlug('ab'), kSlugInvalid);
    expect(validateSlug('Shox Barber'), kSlugInvalid);
    expect(validateSlug(''), 'Slugni kiriting');
  });

  test('diff of an edited tagline is only the tagline', () {
    final s = fxSettings();
    expect(s.copyWith(tagline: 'Yangi shior').diff(s), {'tagline': 'Yangi shior'});
  });

  testWidgets('renders the sections from the API', (t) async {
    await pumpScreen(t, const BookingSettingsScreen(), http: _http());
    await _settle(t);
    expect(find.text('Onlayn yozuv'), findsOneWidget);
    expect(find.text('https://shox-barber.tizbiz.uz'), findsOneWidget);
    await _scrollTo(t, find.text('Ulangan: @shoxbarber_bot'));
    expect(find.text('Ulangan: @shoxbarber_bot'), findsOneWidget);
    await _scrollTo(t, find.text('15 ta sharh'));
    expect(find.text('15 ta sharh'), findsOneWidget);
  });

  testWidgets('offline shows the network error', (t) async {
    await pumpScreen(t, const BookingSettingsScreen(), http: FakeHttp()..onNetworkError('GET', Endpoints.bookingSettings));
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('saving an edited tagline sends only {"tagline"}', (t) async {
    final saved = {...jSettings(), 'tagline': 'Yangi shior'};
    final http = _http()..on('PUT', Endpoints.bookingSettings, body: envelope(saved));
    await pumpScreen(t, const BookingSettingsScreen(), http: http);
    await _settle(t);
    final tagline = find.widgetWithText(TextFormField, 'Shior');
    await _scrollTo(t, tagline);
    await t.enterText(tagline, 'Yangi shior');
    await t.pump(const Duration(milliseconds: 300));
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump(const Duration(milliseconds: 300));
    final save = find.descendant(
        of: find.ancestor(of: tagline, matching: find.byType(Form)), matching: find.widgetWithText(FilledButton, 'Saqlash'));
    await _scrollTo(t, save);
    await t.tap(save);
    await _settle(t);
    final put = http.requests.singleWhere((r) => r.method == 'PUT');
    expect(put.body, {'tagline': 'Yangi shior'});
    expect(find.text('Saqlandi'), findsOneWidget);
  });

  testWidgets('invalid slug blocks saving; 422 slug shows the server text', (t) async {
    final http = _http()
      ..on('PUT', Endpoints.bookingSettings, status: 422, body: apiError(422, 'Bu slug band.', pointer: 'slug'));
    await pumpScreen(t, const BookingSettingsScreen(), http: http);
    await _settle(t);
    final slug = find.widgetWithText(TextFormField, 'Slug');
    await t.enterText(slug, 'AB');
    await t.tap(find.widgetWithText(FilledButton, 'Saqlash').first);
    await _settle(t);
    expect(find.text(kSlugInvalid), findsOneWidget);
    expect(http.requests.where((r) => r.method == 'PUT'), isEmpty);

    await t.enterText(slug, 'shox-new');
    expect(find.text("Slugni o'zgartirsangiz eski havolalar ishlamay qoladi"), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Saqlash').first);
    await _settle(t);
    expect(http.requests.singleWhere((r) => r.method == 'PUT').body, {'slug': 'shox-new'});
    expect(find.text('Bu slug band.'), findsOneWidget);
  });

  testWidgets('telegram connect sends the token and renders the webhook warning', (t) async {
    final resp = {...jSettings(), 'telegram_webhook_ok': false, 'telegram_error': 'Webhook faqat https serverda ishlaydi.'};
    final http = _http()..on('PUT', Endpoints.bookingSettings, body: envelope(resp));
    await pumpScreen(t, const BookingSettingsScreen(), http: http);
    await _settle(t);
    final field = find.widgetWithText(TextField, 'Yangi bot tokeni');
    await _scrollTo(t, field);
    await t.enterText(field, '123:abc');
    await _scrollTo(t, find.text('Ulash'));
    await t.tap(find.text('Ulash'));
    await _settle(t);
    expect(http.requests.singleWhere((r) => r.method == 'PUT').body, {'telegram_bot_token': '123:abc'});
    expect(find.text('Webhook faqat https serverda ishlaydi.'), findsOneWidget);
  });
}
