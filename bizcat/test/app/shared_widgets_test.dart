import 'dart:async';

import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/brand.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/category_icon.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/location_card.dart';
import 'package:bizcat/shared/widgets/phone_field.dart';
import 'package:bizcat/shared/widgets/poller.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/shared/widgets/review_tile.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/pump.dart';

void main() {
  testWidgets('RatingBadge: one decimal with a comma; 0 -> Yangi', (t) async {
    await pumpInApp(t, const Column(children: [RatingBadge(avg: 4.73, count: 15), RatingBadge(avg: 0, count: 0)]));
    expect(find.text('4,7 (15)'), findsOneWidget);
    expect(find.text('Yangi'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('RatingStars renders 5 icons with halves', (t) async {
    await pumpInApp(t, const RatingStars(value: 3.5));
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_half), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  testWidgets('RatingSummaryView', (t) async {
    final summary = RatingSummary.fromJson(Fx.data(Fx.detail)['rating'] as Map<String, dynamic>);
    await pumpInApp(t, RatingSummaryView(summary: summary));
    expect(find.text('4,7'), findsOneWidget);
    expect(find.text('15 ta sharh'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('status chips use the consumer labels', (t) async {
    await pumpInApp(
      t,
      const Column(children: [
        OrderStatusChip(OrderStatus.delivered),
        AppointmentStatusChip(AppointmentStatus.arrived),
        AppointmentStatusChip(AppointmentStatus.canceled),
      ]),
    );
    expect(find.text('Topshirildi'), findsOneWidget);
    expect(find.text('Jarayonda'), findsOneWidget);
    expect(find.text('Bekor qilingan'), findsOneWidget);
  });

  testWidgets('LocationCard: Xaritada ochish opens mapUrl', (t) async {
    final app = await pumpInApp(
      t,
      const LocationCard(address: 'Chilonzor 9-kvartal, 12-uy', mapUrl: 'https://yandex.uz/maps/-/CDabc', phone: '+998901111111'),
    );
    expect(find.text('Manzil'), findsOneWidget);
    expect(find.text('+998 90 111 11 11'), findsOneWidget);
    await t.tap(find.text('Xaritada ochish'));
    await t.pump();
    expect(app.opener.opened.single, Uri.parse('https://yandex.uz/maps/-/CDabc'));
  });

  testWidgets('LocationCard: lat/lng -> yandex pt; nothing known -> hidden', (t) async {
    final app = await pumpInApp(t, const Column(children: [LocationCard(lat: 41.2756, lng: 69.2034), LocationCard()]));
    expect(find.text('Xaritada ochish'), findsOneWidget);
    await t.tap(find.text('Xaritada ochish'));
    await t.pump();
    expect(app.opener.last.toString(), 'https://yandex.uz/maps/?pt=69.2034,41.2756&z=17&l=map');
  });

  testWidgets('LocationCard: a failed open shows the snackbar', (t) async {
    final app = await pumpInApp(t, const LocationCard(address: 'Yunusobod 4-kvartal', name: 'Aziza Tortlari'));
    app.opener.result = false;
    await t.tap(find.text('Xaritada ochish'));
    await t.pump();
    await t.pump();
    expect(app.opener.last?.host, 'maps.google.com');
    expect(app.opener.last?.queryParameters['q'], 'Aziza Tortlari, Yunusobod 4-kvartal');
    expect(find.text("Ochib bo'lmadi."), findsOneWidget);
  });

  testWidgets('BusinessCardTile renders the card fields', (t) async {
    final cards = Fx.items(Fx.cards).map(BusinessCard.fromJson).toList();
    await pumpInApp(t, ListView(children: [for (final c in cards) BusinessCardTile(card: c)]));
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('4,7 (15)'), findsOneWidget);
    expect(find.text('Chilonzor'), findsOneWidget);
    expect(find.text('${Money.format(5000000)} dan'), findsOneWidget);
    expect(find.text('Tavsiya'), findsOneWidget);
    expect(find.text('SB'), findsOneWidget); // network images off -> the initials placeholder
  });

  testWidgets('BusinessCardCompact', (t) async {
    final card = BusinessCard.fromJson(Fx.items(Fx.cards).first);
    await pumpInApp(t, BusinessCardCompact(card: card));
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('4,7'), findsOneWidget);
  });

  testWidgets('BizLogo initials', (t) async {
    expect(BizLogo.initials('Shox Barber'), 'SB');
    expect(BizLogo.initials('aziza tortlari va boshqalar'), 'AT');
    expect(BizLogo.initials(' '), '?');
    await pumpInApp(t, const BizLogo(name: 'Aziza Tortlari', brandColor: '#F26A35'));
    expect(find.text('AT'), findsOneWidget);
  });

  testWidgets('ReviewTile with a reply and a menu', (t) async {
    final review = Review.fromJson(Fx.data(Fx.wrap(Fx.reviewMine)));
    var edited = false;
    await pumpInApp(t, ReviewTile(review: review, showBusiness: true, onEdit: () => edited = true, onDelete: () {}));
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Aziza K.'), findsOneWidget);
    expect(find.text('Soch olish · Usta Jahongir'), findsOneWidget);
    await t.tap(find.byIcon(BzIcons.more));
    await t.pumpAndSettle();
    await t.tap(find.text('Tahrirlash'));
    await t.pumpAndSettle();
    expect(edited, isTrue);

    final withReply = Review.fromJson(Fx.data(Fx.wrap(Fx.reviewPublic)));
    await pumpInApp(t, ReviewTile(review: withReply));
    expect(find.text('Biznes javobi'), findsOneWidget);
    expect(find.text('Rahmat, yana kutamiz!'), findsOneWidget);
  });

  testWidgets('CategoryTile + icon mapping', (t) async {
    expect(categoryIconData('scissors'), BzIcons.scissor);
    expect(categoryIconData('rings'), BzIcons.wedding);
    expect(categoryIconData('zzz'), BzIcons.shop);
    final cat = Category.fromJson(Fx.items(Fx.categories).first);
    await pumpInApp(t, Center(child: CategoryTile(category: cat)));
    expect(find.text('Barber'), findsOneWidget);
    expect(find.text('1 ta'), findsOneWidget);
  });

  testWidgets('PhoneField formats as you type', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await pumpInApp(t, PhoneField(controller: c));
    expect(find.text('+998'), findsOneWidget);
    await t.enterText(find.byType(TextField), '901234567');
    expect(c.text, '90 123 45 67');
    expect(phoneFieldNormalized(c.text), '+998901234567');
    await t.enterText(find.byType(TextField), '+998 90 000 00 01');
    expect(c.text, '90 000 00 01');
    await t.enterText(find.byType(TextField), '12345');
    expect(phoneFieldNormalized(c.text), isNull);
  });

  testWidgets('states: EmptyState / ErrorState / OfflineState', (t) async {
    var retried = 0;
    await pumpInApp(t, ErrorState(message: 'Xatolik yuz berdi.', onRetry: () => retried++));
    expect(find.text('Xatolik yuz berdi.'), findsOneWidget);
    await t.tap(find.text('Qayta urinish'));
    expect(retried, 1);
    await pumpInApp(t, const OfflineState());
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
  });

  testWidgets('AsyncBody: loading, error, offline, empty, data, refreshing', (t) async {
    Future<void> show(AsyncValue<List<int>> v) => pumpInApp(
          t,
          AsyncBody<List<int>>(
            value: v,
            isEmpty: (d) => d.isEmpty,
            empty: const Text('bo\'sh'),
            builder: (d) => Text('n=${d.length}'),
          ),
        );
    await show(const AsyncLoading());
    expect(find.byType(LoadingView), findsOneWidget);
    await show(const AsyncError(ApiException(kind: ApiErrorKind.http, status: 409, detail: 'Tanlangan vaqt band.'), StackTrace.empty));
    expect(find.text('Tanlangan vaqt band.'), findsOneWidget);
    await show(AsyncError(ApiException.network(ApiErrorKind.network), StackTrace.empty));
    expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
    await show(const AsyncData(<int>[]));
    expect(find.text("bo'sh"), findsOneWidget);
    await show(const AsyncData([1, 2]));
    expect(find.text('n=2'), findsOneWidget);
  });

  testWidgets('AsyncBody keeps the data while refreshing', (t) async {
    var calls = 0;
    final gate = <Completer<List<int>>>[];
    final provider = FutureProvider<List<int>>((ref) {
      calls++;
      final c = Completer<List<int>>();
      gate.add(c);
      return c.future;
    });
    final app = await pumpInApp(
      t,
      Consumer(
        builder: (_, ref, _) => AsyncBody<List<int>>(value: ref.watch(provider), builder: (d) => Text('n=${d.length}')),
      ),
    );
    expect(find.byType(LoadingView), findsOneWidget);
    gate.last.complete([1, 2, 3]);
    await t.pump();
    await t.pump();
    expect(find.text('n=3'), findsOneWidget);
    app.container.invalidate(provider);
    await t.pump();
    expect(calls, 2);
    expect(find.text('n=3'), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
    gate.last.complete([1]);
    await t.pump();
    await t.pump();
    expect(find.text('n=1'), findsOneWidget);
  });

  testWidgets('StepHeader + SummaryCard + BusinessMiniHeader', (t) async {
    await pumpInApp(
      t,
      const Column(children: [
        StepHeader(step: 2, total: 4, title: 'Usta'),
        BusinessMiniHeader(name: 'Shox Barber', subtitle: 'Chilonzor'),
        SummaryCard(rows: [
          SummaryRow(label: 'Xizmat', value: 'Soch olish'),
          SummaryRow(label: 'Jami', value: '80 000', emphasize: true),
        ]),
      ]),
    );
    expect(find.text('2-qadam / 4 · Usta'), findsOneWidget);
    expect(find.text('Shox Barber'), findsOneWidget);
    expect(find.text('Jami'), findsOneWidget);
  });

  testWidgets('confirmDialog returns true only on confirm', (t) async {
    await pumpInApp(t, const SizedBox());
    final context = t.element(find.byType(SizedBox).last);
    bool? result;
    final f = confirmDialog(context, title: 'Bekor qilinsinmi?', confirmLabel: 'Ha, bekor qilish', danger: true)
        .then((v) => result = v);
    await t.pumpAndSettle();
    await t.tap(find.text('Ha, bekor qilish'));
    await t.pumpAndSettle();
    await f;
    expect(result, isTrue);
  });

  testWidgets('Poller ticks on its interval and stops when disabled', (t) async {
    var ticks = 0;
    await pumpInApp(t, Poller(interval: const Duration(seconds: 5), onTick: () => ticks++, child: const SizedBox()));
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 5));
    expect(ticks, 2);
    await pumpInApp(
      t,
      Poller(interval: const Duration(seconds: 5), enabled: false, onTick: () => ticks++, child: const SizedBox()),
    );
    await t.pump(const Duration(seconds: 12));
    expect(ticks, 2);
  });

  testWidgets('brand assets render', (t) async {
    await pumpInApp(t, const Column(children: [BrandLogo(width: 90), BrandMark(size: 20), BrandMark(size: 48)]));
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.byType(BrandMark), findsNWidgets(2));
  });

  testWidgets('NetImage shows the placeholder when images are off', (t) async {
    await pumpInApp(t, const NetImage(url: 'https://x.test/a.png', width: 40, height: 40, placeholder: Text('ph')));
    expect(find.text('ph'), findsOneWidget);
  });
}
