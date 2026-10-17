import 'dart:async';

import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/deposit.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const Object _keep = Object();

/// Appointment list scope; wire 'upcoming' | 'past'.
enum ApptScope {
  upcoming('upcoming'),
  past('past');

  const ApptScope(this.wire);

  final String wire;
}

/// Order list scope; wire 'active' | 'past'.
enum OrderScope {
  active('active'),
  past('past');

  const OrderScope(this.wire);

  final String wire;
}

/// Page size of the bookings lists.
const int kBookingsPerPage = 20;

/// A paged list plus the state of its "load more" request.
@immutable
final class PagedState<T> {
  const PagedState({required this.page, this.loadingMore = false, this.moreError});

  /// An empty first page (signed out).
  factory PagedState.empty() => PagedState<T>(
    page: Paged<T>(
      items: const [],
      meta: const PageMeta(page: 1, perPage: kBookingsPerPage, total: 0, pages: 0),
    ),
  );

  final Paged<T> page;
  final bool loadingMore;

  /// The last failed [PagedController.loadMore] error (cleared on the next attempt).
  final Object? moreError;

  List<T> get items => page.items;
  bool get hasMore => page.hasMore;
  bool get isEmpty => page.isEmpty;

  PagedState<T> copyWith({Paged<T>? page, bool? loadingMore, Object? moreError = _keep}) => PagedState<T>(
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
    moreError: identical(moreError, _keep) ? this.moreError : moreError,
  );
}

/// Shared paging logic of the two bookings lists. Signed out -> an empty page.
abstract class PagedController<T> extends AsyncNotifier<PagedState<T>> {
  int _generation = 0;

  /// GET one page.
  Future<Paged<T>> fetchPage(int page);

  @override
  Future<PagedState<T>> build() async {
    final consumerId = ref.watch(consumerIdProvider);
    ref
      ..watch(bookingsRevisionProvider)
      ..watch(reviewsRevisionProvider);
    _generation++;
    if (consumerId == null) return PagedState<T>.empty();
    return PagedState<T>(page: await fetchPage(1));
  }

  /// Appends the next page. Errors land in [PagedState.moreError] (the list stays).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || current.loadingMore || !current.hasMore) return;
    final next = current.page.meta.nextPage;
    if (next == null) return;
    final gen = _generation;
    state = AsyncData(current.copyWith(loadingMore: true, moreError: null));
    try {
      final page = await fetchPage(next);
      if (!ref.mounted || gen != _generation) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(page: latest.page.append(page), loadingMore: false, moreError: null));
    } on Object catch (e) {
      if (!ref.mounted || gen != _generation) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(loadingMore: false, moreError: e));
    }
  }
}

/// GET /v1/consumer/appointments {scope, page, per_page: 20} (consumer shape).
final myAppointmentsProvider = AsyncNotifierProvider.autoDispose
    .family<MyAppointmentsController, PagedState<Appointment>, ApptScope>(MyAppointmentsController.new);

class MyAppointmentsController extends PagedController<Appointment> {
  MyAppointmentsController(this.scope);

  final ApptScope scope;

  @override
  Future<Paged<Appointment>> fetchPage(int page) => ref
      .read(apiProvider)
      .getPage(
        Endpoints.consumerAppointments,
        Appointment.fromJson,
        query: {'scope': scope.wire, 'page': page, 'per_page': kBookingsPerPage},
      );
}

/// GET /v1/consumer/orders {scope, page, per_page: 20} (+ business, can_cancel, can_review, review_id).
final myOrdersProvider = AsyncNotifierProvider.autoDispose.family<MyOrdersController, PagedState<Order>, OrderScope>(
  MyOrdersController.new,
);

class MyOrdersController extends PagedController<Order> {
  MyOrdersController(this.scope);

  final OrderScope scope;

  @override
  Future<Paged<Order>> fetchPage(int page) => ref
      .read(apiProvider)
      .getPage(
        Endpoints.consumerOrders,
        Order.fromJson,
        query: {'scope': scope.wire, 'page': page, 'per_page': kBookingsPerPage},
      );
}

// ---------------------------------------------------------------------------------------------
// Deposit polling (companion of the appointment detail)
// ---------------------------------------------------------------------------------------------

/// After "Payme orqali to'lash": poll every [interval] until paid or [maxWait] passed.
@immutable
final class DepositWatch {
  const DepositWatch({this.awaitingPayment = false, this.timedOut = false, this.ticks = 0});

  static const Duration interval = Duration(seconds: 5);
  static const Duration maxWait = Duration(minutes: 2);

  /// 24 polls of 5 s = 2 minutes. Counted in ticks (not wall clock) so it is deterministic.
  static int get maxTicks => maxWait.inMilliseconds ~/ interval.inMilliseconds;

  /// true while the 5 s poll runs.
  final bool awaitingPayment;

  /// true after [maxWait] passed without a payment.
  final bool timedOut;

  /// Polls done so far.
  final int ticks;
}

/// Keyed by appointment id.
final depositWatchProvider = NotifierProvider.autoDispose.family<DepositWatchController, DepositWatch, int>(
  DepositWatchController.new,
);

class DepositWatchController extends Notifier<DepositWatch> {
  DepositWatchController(this.appointmentId);

  final int appointmentId;

  @override
  DepositWatch build() => const DepositWatch();

  /// Starts (or restarts) the 2-minute wait.
  void start() => state = const DepositWatch(awaitingPayment: true);

  /// One poll. Returns false when not polling (nothing to fetch).
  bool tick() {
    if (!state.awaitingPayment) return false;
    final n = state.ticks + 1;
    state = n >= DepositWatch.maxTicks
        ? DepositWatch(timedOut: true, ticks: n)
        : DepositWatch(awaitingPayment: true, ticks: n);
    return true;
  }

  /// Paid, or the booking is no longer live.
  void stop() => state = const DepositWatch();
}

// ---------------------------------------------------------------------------------------------
// Appointment detail
// ---------------------------------------------------------------------------------------------

/// GET /v1/consumer/appointments/{id}. 404 -> ApiException.isNotFound ('Bron topilmadi.').
final appointmentDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AppointmentDetailController, Appointment, int>(AppointmentDetailController.new);

class AppointmentDetailController extends AsyncNotifier<Appointment> {
  AppointmentDetailController(this.id);

  final int id;

  @override
  Future<Appointment> build() {
    ref.watch(reviewsRevisionProvider);
    return _fetch();
  }

  Future<Appointment> _fetch() => ref
      .read(apiProvider)
      .get<Appointment>(Endpoints.consumerAppointment(id), decode: (d) => Appointment.fromJson(JsonRead.object(d)));

  /// POST /v1/consumer/appointments/{id}/cancel {"reason"?}. true on success (bookings bumped).
  /// Errors (409 `Bu bronni bekor qilib bo'lmaydi.` / the paid text) -> a snackbar and false;
  /// a 409 also re-reads the booking so the actions match the server.
  Future<bool> cancel({String? reason}) async {
    final api = ref.read(apiProvider);
    final revision = ref.read(bookingsRevisionProvider.notifier);
    final r = reason?.trim();
    try {
      final a = await api.post<Appointment>(
        Endpoints.consumerAppointmentCancel(id),
        body: {if (r != null && r.isNotEmpty) 'reason': r},
        decode: (d) => Appointment.fromJson(JsonRead.object(d)),
      );
      revision.bump();
      if (!ref.mounted) return true;
      state = AsyncData(a);
      ref.read(depositWatchProvider(id).notifier).stop();
      return true;
    } on Object catch (e) {
      showErrorSnack(e);
      if (e is ApiException && e.isConflict && ref.mounted) unawaited(refresh());
      return false;
    }
  }

  /// POST /v1/payments/deposit (Payme) and open the checkout; then poll for `paid`.
  /// Errors -> a snackbar (a 409 such as `Bu bron uchun to'lov allaqachon qilingan.` re-reads).
  Future<void> payDeposit() async {
    final deposit = ref.read(depositServiceProvider);
    try {
      await deposit.startPayme(id);
      if (!ref.mounted) return;
      ref.read(depositWatchProvider(id).notifier).start();
    } on Object catch (e) {
      showErrorSnack(e);
      if (e is ApiException && e.isConflict && ref.mounted) unawaited(refresh());
    }
  }

  /// One deposit poll tick (Poller): counts the tick, then [refresh]es.
  Future<void> pollDeposit() async {
    if (!ref.read(depositWatchProvider(id).notifier).tick()) return;
    await refresh();
  }

  /// GET again without a loading state. When `paid` flips to true: bookings bumped, the poll stops
  /// and the snackbar `To'lov qabul qilindi.`. [silent] false shows an error snackbar on failure.
  Future<void> refresh({bool silent = true}) async {
    final before = state.value;
    final revision = ref.read(bookingsRevisionProvider.notifier);
    try {
      final a = await _fetch();
      if (!ref.mounted) return;
      state = AsyncData(a);
      final watch = ref.read(depositWatchProvider(id).notifier);
      if (a.paid && before != null && !before.paid) {
        watch.stop();
        revision.bump();
        showSnack("To'lov qabul qilindi.");
      } else if (a.paid || !a.status.isLive) {
        watch.stop();
      }
    } on Object catch (e) {
      if (!ref.mounted) return;
      if (state.hasError || !state.hasValue) {
        state = AsyncError(e, StackTrace.current);
      } else if (!silent) {
        showErrorSnack(e);
      } else {
        debugPrint('bookings: appointment $id refresh failed: $e');
      }
    }
  }
}

// ---------------------------------------------------------------------------------------------
// Order detail
// ---------------------------------------------------------------------------------------------

/// GET /v1/consumer/orders/{id}. 404 -> ApiException.isNotFound ('Buyurtma topilmadi.').
final orderDetailProvider = AsyncNotifierProvider.autoDispose.family<OrderDetailController, Order, int>(
  OrderDetailController.new,
);

class OrderDetailController extends AsyncNotifier<Order> {
  OrderDetailController(this.id);

  final int id;

  @override
  Future<Order> build() {
    ref.watch(reviewsRevisionProvider);
    return _fetch();
  }

  Future<Order> _fetch() =>
      ref.read(apiProvider).get<Order>(Endpoints.consumerOrder(id), decode: (d) => Order.fromJson(JsonRead.object(d)));

  /// POST /v1/consumer/orders/{id}/cancel (no body). true on success (bookings bumped).
  /// Errors (409 `Buyurtmani faqat yangi holatda bekor qilish mumkin.`) -> a snackbar and false.
  Future<bool> cancel() async {
    final api = ref.read(apiProvider);
    final revision = ref.read(bookingsRevisionProvider.notifier);
    try {
      final o = await api.post<Order>(
        Endpoints.consumerOrderCancel(id),
        decode: (d) => Order.fromJson(JsonRead.object(d)),
      );
      revision.bump();
      if (!ref.mounted) return true;
      state = AsyncData(o);
      return true;
    } on Object catch (e) {
      showErrorSnack(e);
      if (e is ApiException && e.isConflict && ref.mounted) unawaited(refresh());
      return false;
    }
  }

  /// GET again without a loading state (the 30 s poll of an active order, pull-to-refresh).
  Future<void> refresh({bool silent = true}) async {
    final before = state.value;
    final revision = ref.read(bookingsRevisionProvider.notifier);
    try {
      final o = await _fetch();
      if (!ref.mounted) return;
      state = AsyncData(o);
      if (before != null && before.status != o.status) revision.bump();
    } on Object catch (e) {
      if (!ref.mounted) return;
      if (state.hasError || !state.hasValue) {
        state = AsyncError(e, StackTrace.current);
      } else if (!silent) {
        showErrorSnack(e);
      } else {
        debugPrint('bookings: order $id refresh failed: $e');
      }
    }
  }
}

/// Order is still moving through the board (polled while visible).
bool isActiveOrder(OrderStatus s) =>
    s == OrderStatus.newOrder || s == OrderStatus.confirmed || s == OrderStatus.preparing || s == OrderStatus.ready;
