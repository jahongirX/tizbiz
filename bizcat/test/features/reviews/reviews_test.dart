import 'package:bizcat/app/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump.dart';

final String _newPath = AppRoutes.reviewNew(appointmentId: 4990, businessName: 'Shox Barber');

void main() {
  testWidgets('submit without a rating shows the error and sends nothing', (t) async {
    final h = await pumpBizcat(t, location: _newPath, signedIn: true);

    expect(find.text("Shox Barber qanday bo'ldi?"), findsOneWidget);
    await t.tap(find.text('Yuborish'));
    await settle(t);

    expect(find.text('Baho tanlang.'), findsOneWidget);
    expect(h.api.called('POST', '/v1/consumer/reviews'), isFalse);
  });

  testWidgets('5 stars + text posts the review', (t) async {
    final h = await pumpBizcat(
      t,
      location: _newPath,
      signedIn: true,
      setup: (api) => api.on('POST', '/v1/consumer/reviews', status: 201, body: Fx.wrap(Fx.reviewMine)),
    );

    await t.tap(find.byKey(const ValueKey('star-5')));
    await t.pump();
    expect(find.text("A'lo"), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Juda yoqdi!');
    await t.tap(find.text('Yuborish'));
    await settle(t);

    expect(h.api.last('POST', '/v1/consumer/reviews').json, {
      'appointment_id': 4990,
      'rating': 5,
      'comment': 'Juda yoqdi!',
    });
    expect(find.text('Rahmat! Sharhingiz qabul qilindi.'), findsOneWidget);
    expect(h.location, startsWith(AppRoutes.bookings));
  });

  testWidgets('409 shows the server text with a back button', (t) async {
    await pumpBizcat(
      t,
      location: _newPath,
      signedIn: true,
      setup: (api) => api.on(
        'POST',
        '/v1/consumer/reviews',
        status: 409,
        body: Fx.error(409, 'Bu tashrif uchun sharh allaqachon qoldirilgan.'),
      ),
    );

    await t.tap(find.byKey(const ValueKey('star-4')));
    await t.tap(find.text('Yuborish'));
    await settle(t);

    expect(find.text('Bu tashrif uchun sharh allaqachon qoldirilgan.'), findsOneWidget);
    expect(find.text('Orqaga'), findsOneWidget);
  });

  testWidgets('422 comment pointer shows a field error', (t) async {
    await pumpBizcat(
      t,
      location: _newPath,
      signedIn: true,
      setup: (api) => api.on(
        'POST',
        '/v1/consumer/reviews',
        status: 422,
        body: Fx.error(422, "Izoh juda uzun.", pointer: 'comment'),
      ),
    );

    await t.tap(find.byKey(const ValueKey('star-3')));
    await t.tap(find.text('Yuborish'));
    await settle(t);

    expect(find.text('Izoh juda uzun.'), findsOneWidget);
  });

  testWidgets('edit mode prefills from mine and patches', (t) async {
    final h = await pumpBizcat(
      t,
      location: AppRoutes.reviewEdit(88),
      signedIn: true,
      setup: (api) => api
        ..on('GET', '/v1/consumer/reviews', body: Fx.myReviews)
        ..on('PATCH', '/v1/consumer/reviews/88', body: Fx.wrap(Fx.reviewMine)),
    );

    expect(find.text('Sharhni tahrirlash'), findsOneWidget);
    expect(find.text("Usta juda e'tiborli, soch ajoyib chiqdi!"), findsOneWidget);
    expect(find.text("A'lo"), findsOneWidget);
    expect(find.text("Sharhni o'chirish"), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('star-4')));
    await t.enterText(find.byType(TextField), 'Yaxshi edi.');
    await t.tap(find.text('Saqlash'));
    await settle(t);

    expect(h.api.last('PATCH', '/v1/consumer/reviews/88').json, {'rating': 4, 'comment': 'Yaxshi edi.'});
  });

  testWidgets('edit mode of an unknown review shows not found', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.reviewEdit(999),
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/consumer/reviews', body: Fx.myReviews),
    );

    expect(find.text('Sharh topilmadi'), findsOneWidget);
  });

  testWidgets('my reviews renders the business and the reply box', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.myReviews,
      signedIn: true,
      setup: (api) => api.on(
        'GET',
        '/v1/consumer/reviews',
        body: {
          'data': [
            {...Fx.reviewMine, 'reply': 'Rahmat, yana kutamiz!', 'replied_at': 1791636000},
            {...Fx.reviewMine, 'id': 89, 'status': 'hidden', 'appointment_id': 4991},
          ],
        },
      ),
    );

    expect(find.text('Sharhlarim'), findsOneWidget);
    expect(find.text('Shox Barber'), findsWidgets);
    expect(find.text('Biznes javobi'), findsOneWidget);
    expect(find.text('Yashirilgan'), findsOneWidget);
  });

  testWidgets('my reviews empty state', (t) async {
    await pumpBizcat(
      t,
      location: AppRoutes.myReviews,
      signedIn: true,
      setup: (api) => api.on('GET', '/v1/consumer/reviews', body: Fx.emptyList),
    );

    expect(find.text('Hali sharh qoldirmagansiz'), findsOneWidget);
  });
}
