import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/features/staff_admin/staff_list_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('renders active staff with commission and link chip', (tester) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.staff, body: envelope([jStaff(), jStaff(id: 3, name: 'Eski usta', userId: null, isActive: false)]));
    await pumpScreen(tester, const StaffListScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Ustalar'), findsOneWidget);
    expect(find.text('Usta Jahongir'), findsOneWidget);
    expect(find.text('Komissiya 40%'), findsOneWidget);
    expect(find.text("Hisob bog'langan"), findsOneWidget);
    expect(find.text('Eski usta'), findsNothing);

    await tester.tap(find.text("Nofaollarni ko'rsatish"));
    await tester.pump();
    expect(find.text('Eski usta'), findsOneWidget);
    expect(find.text('Nofaol'), findsOneWidget);
  });

  testWidgets('empty list', (tester) async {
    final http = FakeHttp()..on('GET', Endpoints.staff, body: envelope(<Object>[]));
    await pumpScreen(tester, const StaffListScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Hali xodimlar yo'q"), findsOneWidget);
  });

  testWidgets('offline', (tester) async {
    final http = FakeHttp()..onNetworkError('GET', Endpoints.staff);
    await pumpScreen(tester, const StaffListScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });
}
