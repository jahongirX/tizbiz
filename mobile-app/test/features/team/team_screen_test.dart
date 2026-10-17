import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/team/team_screen.dart';
import 'package:tizbiz_biznes/features/team/widgets/member_tile.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

FakeHttp _http({List<Map<String, dynamic>>? team, List<Map<String, dynamic>>? staff}) => FakeHttp()
  ..on('GET', Endpoints.team, body: envelope(team ?? jTeam()))
  ..on('GET', Endpoints.staff, body: envelope(staff ?? [jStaff()]));

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('owner sees members, staff link, Siz chip and the FAB', (t) async {
    await pumpScreen(t, const TeamScreen(), http: _http());
    await _settle(t);
    expect(find.text('Shoxrux Karimov'), findsOneWidget);
    expect(find.text('+998 93 111 00 01'), findsOneWidget);
    expect(find.text('Xodim: Usta Jahongir'), findsOneWidget);
    expect(find.text("Xodimga bog'lanmagan"), findsOneWidget);
    expect(find.text('Siz'), findsOneWidget);
    expect(find.text("A'zo qo'shish"), findsOneWidget);
  });

  testWidgets('admin sees the list read-only with no FAB', (t) async {
    await pumpScreen(t, const TeamScreen(), role: BizRole.admin, http: _http());
    await _settle(t);
    expect(find.text('Usta Jahongir'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(PopupMenuButton<MemberAction>), findsNothing);
    expect(find.text("Faqat biznes egasi jamoani o'zgartira oladi."), findsOneWidget);
  });

  testWidgets('offline shows the network error', (t) async {
    final http = FakeHttp()..onNetworkError('GET', Endpoints.team);
    await pumpScreen(t, const TeamScreen(), http: http);
    await _settle(t);
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('add form requires phone and name; 409 shows a banner', (t) async {
    final http = _http()
      ..on('POST', Endpoints.team, status: 409, body: apiError(409, "Bu foydalanuvchi allaqachon jamoa a'zosi."));
    await pumpScreen(t, const TeamScreen(), http: http);
    await _settle(t);
    await t.tap(find.text("A'zo qo'shish"));
    await _settle(t);
    await t.tap(find.text("Qo'shish"));
    await t.pump();
    expect(find.text("Telefon raqam noto'g'ri"), findsOneWidget);
    expect(find.text('Ismni kiriting'), findsOneWidget);
    expect(http.requests.where((r) => r.method == 'POST'), isEmpty);

    await t.enterText(find.widgetWithText(TextFormField, 'Telefon'), '931112233');
    await t.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Yangi Usta');
    await t.tap(find.text("Qo'shish"));
    await _settle(t);
    final post = http.requests.lastWhere((r) => r.method == 'POST');
    expect(post.body, {'phone': '+998931112233', 'name': 'Yangi Usta', 'role': 'staff'});
    expect(find.text("Bu foydalanuvchi allaqachon jamoa a'zosi."), findsOneWidget);
  });

  testWidgets('editing the link sends only staff_id', (t) async {
    final team = [
      jTeam().first,
      {'user_id': 31, 'name': 'Usta Jahongir', 'phone': '+998931110001', 'role': 'staff', 'staff_id': null},
    ];
    final http = _http(team: team, staff: [jStaff(name: 'Usta profili', userId: null)])
      ..on('PATCH', Endpoints.teamMember(31), body: envelope({'user_id': 31, 'role': 'staff', 'staff_id': 2}));
    await pumpScreen(t, const TeamScreen(), http: http);
    await _settle(t);
    await t.tap(find.byType(PopupMenuButton<MemberAction>).last);
    await _settle(t);
    await t.tap(find.text('Tahrirlash'));
    await _settle(t);
    await t.tap(find.text("Bog'lamaslik"));
    await _settle(t);
    await t.tap(find.text('Usta profili').last);
    await _settle(t);
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    final patch = http.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, Endpoints.teamMember(31));
    expect(patch.body, {'staff_id': 2});
  });
}
