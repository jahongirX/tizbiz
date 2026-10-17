import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/appointments/actions.dart';
import 'package:tizbiz_biznes/features/appointments/appointment_create_screen.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

class FakeAppointmentActions implements AppointmentActions {
  final created = <({Map<String, dynamic> body, String key})>[];
  ApiException? createError;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  Future<ApiResponse<Appointment>> create(AdminBookingRequest req, String idempotencyKey) async {
    created.add((body: req.toJson(), key: idempotencyKey));
    final e = createError;
    if (e != null) throw e;
    return ApiResponse(statusCode: 201, data: fxAppointment());
  }

  @override
  Future<Appointment> setStatus(int id, AppointmentStatus next) async => fxAppointment(status: next);

  @override
  Future<DepositCheckout> depositLink(int appointmentId) => throw UnimplementedError();
}

void main() {
  late FakeAppointmentActions actions;

  setUp(() => actions = FakeAppointmentActions());

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpScreen(
      t,
      const AppointmentCreateScreen(initialStaffId: 2),
      overrides: [
        appointmentActionsProvider.overrideWithValue(actions),
        activeStaffProvider.overrideWithValue(AsyncData([fxStaff()])),
        servicesListProvider.overrideWith((ref) async => [fxService()]),
        serviceCategoriesProvider.overrideWith((ref) async => [fxCategory()]),
        availabilityProvider.overrideWith(
          (ref, k) async => Availability.fromJson({
            'date': k.date.toIso(),
            'timezone': 'Asia/Tashkent',
            'slots': [
              {'start_utc': '2026-10-17 13:00:00', 'end_utc': '2026-10-17 13:40:00', 'start_local': '18:00'},
            ],
          }),
        ),
        clientSearchProvider.overrideWith((ref, q) async => [fxClient()]),
      ],
    );
    await _settle(t);
  }

  testWidgets('empty submit shows the required errors and sends nothing', (t) async {
    await pump(t);
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    expect(find.text('Xizmatni tanlang'), findsWidgets);
    expect(find.text('Vaqtni tanlang'), findsOneWidget);
    expect(find.text('Mijozni tanlang'), findsOneWidget);
    expect(actions.created, isEmpty);
  });

  testWidgets('slot + new client sends the expected body; 409 shows under the time', (t) async {
    actions.createError = ApiException.fromResponse(409, apiError(409, 'Tanlangan vaqt band.'), const {});
    await pump(t);
    await t.tap(find.byKey(const ValueKey('service')));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Soch olish + soqol ·').last);
    await t.pumpAndSettle();
    await t.tap(find.text('18:00'));
    await _settle(t);
    await t.tap(find.text('Yangi mijoz'));
    await _settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Ism'), 'Ali Valiyev');
    await t.enterText(find.widgetWithText(TextFormField, 'Telefon'), '901234567');
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    expect(actions.created, hasLength(1));
    expect(actions.created.single.body, {
      'staff_id': 2,
      'service_id': 11,
      'starts_at': '2026-10-17 13:00:00',
      'client': {'phone': '+998901234567', 'name': 'Ali Valiyev'},
      'status': 'pending',
    });
    expect(find.text('Tanlangan vaqt band.'), findsOneWidget);

    // Retry without changes reuses the idempotency key.
    await t.tap(find.text('Saqlash'));
    await _settle(t);
    expect(actions.created, hasLength(2));
    expect(actions.created[1].key, actions.created[0].key);
  });
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
}
