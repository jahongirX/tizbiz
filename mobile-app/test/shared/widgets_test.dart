import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/shared/polling.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/business_avatar.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/day_switcher.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/kpi_card.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/money_text.dart';
import 'package:tizbiz_biznes/shared/widgets/paged_list_view.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/som_field.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_biznes/shared/widgets/star_rating.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/test_app.dart';

Widget _body(AsyncValue<List<int>> v) => Scaffold(
      body: AsyncBody<List<int>>(
        value: v,
        isEmpty: (d) => d.isEmpty,
        empty: const EmptyView(icon: Icons.inbox, title: "Bo'sh"),
        onRetry: () {},
        data: (d) => ListView(children: [for (final i in d) Text('row $i')]),
      ),
    );

void main() {
  group('AsyncBody', () {
    testWidgets('loading', (tester) async {
      await pumpScreen(tester, _body(const AsyncLoading()));
      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('data', (tester) async {
      await pumpScreen(tester, _body(const AsyncData([1, 2])));
      expect(find.text('row 1'), findsOneWidget);
      expect(find.text('row 2'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('empty', (tester) async {
      await pumpScreen(tester, _body(const AsyncData([])));
      expect(find.text("Bo'sh"), findsOneWidget);
    });

    testWidgets('network error -> offline view with retry', (tester) async {
      const e = ApiException(kind: ApiErrorKind.network, status: 0);
      await pumpScreen(tester, _body(const AsyncError(e, StackTrace.empty)));
      expect(find.text("Internet aloqasi yo'q"), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });

    testWidgets('error with old data -> stale banner over the data', (tester) async {
      const e = ApiException(kind: ApiErrorKind.http, status: 500, detail: 'Server xatosi');
      var calls = 0;
      final flaky = FutureProvider.autoDispose<List<int>>((ref) async {
        calls++;
        if (calls > 1) throw e;
        return [7];
      });
      await pumpScreen(tester, Consumer(builder: (context, ref, _) => _body(ref.watch(flaky))));
      await tester.pump();
      expect(find.text('row 7'), findsOneWidget);
      ProviderScope.containerOf(tester.element(find.text('row 7'))).invalidate(flaky);
      await tester.pump();
      await tester.pump();
      expect(find.text('row 7'), findsOneWidget);
      expect(find.textContaining("Ma'lumot yangilanmadi: Server xatosi"), findsOneWidget);
    });

    testWidgets('refreshing with data -> 2 px progress bar', (tester) async {
      var calls = 0;
      final never = Completer<List<int>>();
      final slow = FutureProvider.autoDispose<List<int>>((ref) async {
        calls++;
        return calls > 1 ? never.future : [3];
      });
      await pumpScreen(tester, Consumer(builder: (context, ref, _) => _body(ref.watch(slow))));
      await tester.pump();
      ProviderScope.containerOf(tester.element(find.text('row 3'))).invalidate(slow);
      await tester.pump();
      expect(find.text('row 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('ErrorView', () {
    testWidgets('403 calls onForbidden', (tester) async {
      final session = await pumpScreen(
        tester,
        const Scaffold(body: ErrorView(error: ApiException(kind: ApiErrorKind.http, status: 403))),
      );
      await tester.pump();
      expect(find.text("Bu bo'lim uchun ruxsatingiz yo'q."), findsOneWidget);
      expect(session.forbiddenCount, 1);
    });

    testWidgets('401 logs out after the frame', (tester) async {
      final session = await pumpScreen(
        tester,
        const Scaffold(body: ErrorView(error: ApiException(kind: ApiErrorKind.http, status: 401))),
      );
      await tester.pump();
      expect(session.unauthorizedCount, 1);
    });

    testWidgets('404 shows Topilmadi.', (tester) async {
      await pumpScreen(tester, const Scaffold(body: ErrorView(error: ApiException(kind: ApiErrorKind.http, status: 404))));
      expect(find.text('Topilmadi.'), findsOneWidget);
    });
  });

  testWidgets('PhoneField formats as you type and validates', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await pumpScreen(
      tester,
      Scaffold(body: Form(key: formKey, child: PhoneField(controller: controller))),
    );
    await tester.enterText(find.byType(TextFormField), '901234567');
    expect(controller.text, '90 123 45 67');
    expect(Phone.normalize(controller.text), '+998901234567');
    expect(formKey.currentState!.validate(), isTrue);
    await tester.enterText(find.byType(TextFormField), '9012');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text(PhoneField.invalidMessage), findsOneWidget);
  });

  testWidgets('SomField "150 000" -> 15000000 tiyin', (tester) async {
    int? value;
    await pumpScreen(tester, Scaffold(body: SomField(label: 'Narxi', onChanged: (v) => value = v)));
    await tester.enterText(find.byType(TextFormField), '150 000');
    expect(value, 15000000);
    await tester.enterText(find.byType(TextFormField), '150000');
    expect(value, 15000000);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, Money.group(150000));
  });

  testWidgets('SomField shows the initial value grouped', (tester) async {
    await pumpScreen(tester, Scaffold(body: SomField(label: 'Narxi', initialTiyin: 8000000, onChanged: (_) {})));
    expect(find.text(Money.group(80000)), findsOneWidget);
  });

  testWidgets("status badges use the core labels", (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: Column(children: [
          AppointmentStatusBadge(AppointmentStatus.pending),
          AppointmentStatusBadge(AppointmentStatus.noShow),
          OrderStatusBadge(OrderStatus.preparing),
          OrderStatusBadge(OrderStatus.cancelled),
        ]),
      ),
    );
    expect(find.text('Kutilmoqda'), findsOneWidget);
    expect(find.text('Kelmadi'), findsOneWidget);
    expect(find.text('Tayyorlanmoqda'), findsOneWidget);
    expect(find.text('Bekor qilingan'), findsOneWidget);
  });

  testWidgets('StaffNotLinkedView text and recheck', (tester) async {
    final session = await pumpScreen(tester, const Scaffold(body: StaffNotLinkedView()), role: BizRole.staff);
    expect(find.text("Hisobingiz xodimga bog'lanmagan"), findsOneWidget);
    expect(
      find.text("Biznes egasidan Jamoa bo'limida hisobingizni xodim profiliga bog'lashni so'rang."),
      findsOneWidget,
    );
    await tester.tap(find.text('Qayta tekshirish'));
    expect(session.refreshMeCount, 1);
  });

  testWidgets('PollWhileVisible does not tick when disabled', (tester) async {
    var ticks = 0;
    await pumpScreen(
      tester,
      PollWhileVisible(interval: const Duration(seconds: 1), onTick: () => ticks++, child: const SizedBox()),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(ticks, 0);
  });

  testWidgets('PollWhileVisible ticks when enabled and stops on dispose', (tester) async {
    var ticks = 0;
    await pumpScreen(
      tester,
      PollWhileVisible(interval: const Duration(seconds: 1), onTick: () => ticks++, child: const SizedBox()),
      overrides: [pollingEnabledProvider.overrideWithValue(true)],
    );
    await tester.pump(const Duration(milliseconds: 3500));
    expect(ticks, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(ticks, 3);
  });

  testWidgets('MoneyText, PhoneLink, StarRating, KpiCard, BusinessAvatar, FormErrorBanner', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(
        body: Column(children: [
          MoneyText(15000000),
          MoneyText(null),
          MoneyText(150000000, compact: true),
          PhoneLink('+998901234567'),
          StarRating(value: 4.5),
          KpiCard(label: 'Daromad', value: '480 ming', sub: 'jami'),
          BusinessAvatar(name: 'Shox Barber'),
          FormErrorBanner(message: 'Xato'),
          FormErrorBanner(),
        ]),
      ),
    );
    expect(find.text(Money.format(15000000)), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text("1,5 mln so'm"), findsOneWidget);
    expect(find.text('+998 90 123 45 67'), findsOneWidget);
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.text('480 ming'), findsOneWidget);
    expect(find.text('SB'), findsOneWidget);
    expect(find.text('Xato'), findsOneWidget);
  });

  testWidgets('confirmAction returns true only on confirm', (tester) async {
    bool? result;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await confirmAction(context, title: "O'chirilsinmi?", destructive: true),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text("O'chirilsinmi?"), findsOneWidget);
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('DaySwitcher moves by a day and back to today', (tester) async {
    LocalDate? picked;
    const today = LocalDate(2026, 10, 17);
    await pumpScreen(
      tester,
      Scaffold(body: DaySwitcher(date: const LocalDate(2026, 10, 18), today: today, onChanged: (d) => picked = d)),
    );
    expect(find.text('Yakshanba, 18 oktabr'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(picked, today);
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(picked, const LocalDate(2026, 10, 19));
    await tester.tap(find.text('Bugun'));
    expect(picked, today);
  });

  group('PeriodChips', () {
    const today = LocalDate(2026, 10, 17);

    test('preset ranges', () {
      expect(PeriodPreset.today.range(today).key, (from: today, to: today));
      expect(PeriodPreset.week.range(today).from, const LocalDate(2026, 10, 12));
      expect(PeriodPreset.month.range(today).from, const LocalDate(2026, 10, 1));
      expect(PeriodPreset.last7.range(today).days, 7);
      expect(PeriodPreset.last30.range(today).from, const LocalDate(2026, 9, 18));
      expect(PeriodPreset.last90.range(today).days, 90);
      final prev = PeriodPreset.prevMonth.range(today);
      expect((prev.from, prev.to), (const LocalDate(2026, 9, 1), const LocalDate(2026, 9, 30)));
    });

    testWidgets('tapping a preset reports its range', (tester) async {
      DateRangeValue? v;
      await pumpScreen(
        tester,
        Scaffold(
          body: PeriodChips(
            value: PeriodPreset.last7.range(today),
            presets: const [PeriodPreset.last7, PeriodPreset.last30, PeriodPreset.custom],
            onChanged: (x) => v = x,
          ),
        ),
      );
      await tester.tap(find.text('30 kun'));
      expect(v, PeriodPreset.last30.range(today));
    });
  });

  testWidgets('PagedListView asks for more near the end', (tester) async {
    var loads = 0;
    final page = Paged<int>(
      items: List.generate(40, (i) => i),
      meta: const PageMeta(page: 1, perPage: 40, total: 80, pages: 2),
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: PagedListView<int>(
          page: page,
          itemBuilder: (_, i) => SizedBox(height: 50, child: Text('item $i')),
          onLoadMore: () async => loads++,
          onRefresh: () async {},
        ),
      ),
    );
    expect(loads, 0);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    expect(loads, 1);
  });
}
