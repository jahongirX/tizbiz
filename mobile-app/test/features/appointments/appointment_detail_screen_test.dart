import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/appointments/appointment_detail_screen.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('confirmed shows exactly the adminNext buttons; Keldi patches the status', (t) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.appointment(5012), body: envelope(jAppointment()))
      ..on('GET', Endpoints.appointment(5012), body: envelope(jAppointment(status: AppointmentStatus.arrived)))
      ..on('PATCH', Endpoints.appointment(5012), body: envelope(jAppointment(status: AppointmentStatus.arrived)));
    _tall(t);
    await pumpScreen(t, const AppointmentDetailScreen(appointmentId: 5012), http: http);
    await _settle(t);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('Soch olish + soqol'), findsOneWidget);
    for (final label in ['Keldi', 'Yakunlash', 'Kelmadi', 'Bekor qilish']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Tasdiqlash'), findsNothing);

    await t.ensureVisible(find.text('Keldi'));
    await t.tap(find.text('Keldi'));
    await _settle(t);
    final patch = http.calls(Endpoints.appointment(5012), method: 'PATCH').single;
    expect(patch.body, {'status': 'arrived'});
    expect(find.text('Holat yangilandi'), findsOneWidget);
  });

  testWidgets('completed shows no status buttons', (t) async {
    final http = FakeHttp()
      ..on(
        'GET',
        Endpoints.appointment(4990),
        body: envelope(jAppointment(id: 4990, status: AppointmentStatus.completed)),
      );
    _tall(t);
    await pumpScreen(t, const AppointmentDetailScreen(appointmentId: 4990), http: http);
    await _settle(t);
    expect(find.text('Bu yozuv yakunlangan'), findsOneWidget);
    expect(find.text('Yakunlash'), findsNothing);
    expect(find.text('Bekor qilish'), findsNothing);
  });

  testWidgets('409 on status change shows the server detail', (t) async {
    final http = FakeHttp()
      ..on('GET', Endpoints.appointment(5012), body: envelope(jAppointment()))
      ..on(
        'PATCH',
        Endpoints.appointment(5012),
        status: 409,
        body: apiError(409, "Holatni 'completed' dan 'arrived' ga o'zgartirib bo'lmaydi."),
      );
    _tall(t);
    await pumpScreen(t, const AppointmentDetailScreen(appointmentId: 5012), http: http);
    await _settle(t);
    await t.ensureVisible(find.text('Keldi'));
    await t.tap(find.text('Keldi'));
    await _settle(t);
    expect(find.text("Holatni 'completed' dan 'arrived' ga o'zgartirib bo'lmaydi."), findsOneWidget);
  });

  testWidgets('404 shows the not-found text', (t) async {
    _tall(t);
    await pumpScreen(t, const AppointmentDetailScreen(appointmentId: 1), http: FakeHttp());
    await _settle(t);
    expect(find.text('Yozuv topilmadi'), findsOneWidget);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}
