import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/reviews/reviews_screen.dart';
import 'package:tizbiz_biznes/features/reviews/widgets/reply_sheet.dart';
import 'package:tizbiz_biznes/features/reviews/widgets/review_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../../support/test_app.dart';

FakeHttp _http({List<Map<String, dynamic>>? rows}) => FakeHttp()
  ..on('GET', Endpoints.reviews, body: envelope(rows ?? [jReview(), jReview(id: 89, rating: 3, reply: 'Rahmat!', status: 'hidden')], meta: jRatingMeta()));

void main() {
  testWidgets('summary bars and cards render', (tester) async {
    final http = _http();
    await pumpScreen(tester, const ReviewsScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('15 ta sharh'), findsOneWidget);
    for (var s = 1; s <= 5; s++) {
      expect(find.byKey(ValueKey('rating-bar-$s')), findsOneWidget);
    }
    expect(find.text('12'), findsOneWidget);
    expect(find.byType(ReviewCard), findsNWidgets(2));
    expect(find.text("Usta juda e'tiborli!"), findsNWidgets(2));
    expect(find.text('Soch olish · Usta Jahongir'), findsNWidgets(2));
    expect(find.text('Yashirilgan'), findsOneWidget);
    expect(find.text('Sizning javobingiz'), findsOneWidget);
    expect(find.text('Javob berish'), findsOneWidget);
    expect(find.text('Javobni tahrirlash'), findsOneWidget);
    expect(http.calls(Endpoints.reviews).single.query, {'page': '1', 'per_page': '20'});

    await tester.tap(find.text('Javobsiz'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(http.calls(Endpoints.reviews).last.query, {'has_reply': '0', 'page': '1', 'per_page': '20'});
  });

  testWidgets('reply sheet validates empty text and replaces the reply after success', (tester) async {
    final http = _http(rows: [jReview()])
      ..on('POST', Endpoints.reviewReply(88), body: envelope(jReview(reply: 'Rahmat! Sizni yana kutamiz.')));
    await pumpScreen(tester, const ReviewsScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Javob berish'));
    await tester.pumpAndSettle();
    expect(find.byType(ReplySheet), findsOneWidget);

    await tester.tap(find.text('Yuborish'));
    await tester.pump();
    expect(find.text('Javob matnini kiriting'), findsOneWidget);
    expect(http.calls(Endpoints.reviewReply(88)), isEmpty);

    await tester.enterText(find.byType(TextFormField), 'Rahmat! Sizni yana kutamiz.');
    await tester.tap(find.text('Yuborish'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(http.calls(Endpoints.reviewReply(88)).single.body, {'reply': 'Rahmat! Sizni yana kutamiz.'});
    expect(find.byType(ReplySheet), findsNothing);
    expect(find.text('Rahmat! Sizni yana kutamiz.'), findsOneWidget);
    expect(find.text('Javobni tahrirlash'), findsOneWidget);
    expect(http.calls(Endpoints.reviews).length, 1); // replaced in place, no refetch
  });

  testWidgets('422 pointer reply shows on the field', (tester) async {
    final http = _http(rows: [jReview()])
      ..on('POST', Endpoints.reviewReply(88), status: 422, body: {
        'errors': [
          {'status': '422', 'title': 'Validation', 'detail': "Javob juda uzun.", 'source': {'pointer': 'reply'}},
        ],
      });
    await pumpScreen(tester, const ReviewsScreen(), http: http);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Javob berish'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Salom');
    await tester.tap(find.text('Yuborish'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Javob juda uzun.'), findsOneWidget);
    expect(find.byType(ReplySheet), findsOneWidget);
  });

  testWidgets('empty list shows the empty text', (tester) async {
    await pumpScreen(tester, const ReviewsScreen(), http: _http(rows: []));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(kReviewsEmpty), findsOneWidget);
  });

  testWidgets('offline shows the offline view', (tester) async {
    await pumpScreen(tester, const ReviewsScreen(), http: FakeHttp()..offline = true);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  test('validateReply', () {
    expect(validateReply('   '), isNotNull);
    expect(validateReply('a' * 1001), isNotNull);
    expect(validateReply('Rahmat'), isNull);
  });
}
