import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

typedef MoneyRange = ({LocalDate from, LocalDate to});
typedef FinanceFilterValue = ({String? provider, String? type, String? status});
typedef FinanceQuery = ({LocalDate from, LocalDate to, String? provider, String? type, String? status});

/// Wire values of the finance filters (labels in the UI).
const kFinanceProviders = ['payme', 'click'];
const kFinanceTypes = ['deposit', 'refund', 'float'];
const kFinanceStatuses = ['created', 'pending', 'paid', 'canceled', 'refunded'];

/// 'payme' -> 'Payme'.
String providerLabel(String p) => p.isEmpty ? '—' : '${p[0].toUpperCase()}${p.substring(1)}';

final class FinanceRange extends Notifier<DateRangeValue> {
  @override
  DateRangeValue build() => PeriodPreset.last30.range(bizToday(ref.read(clockProvider), ref.watch(activeBusinessProvider)));

  void set(DateRangeValue value) => state = value;
}

final financeRangeProvider = NotifierProvider.autoDispose<FinanceRange, DateRangeValue>(FinanceRange.new);

final class FinanceFilters extends Notifier<FinanceFilterValue> {
  @override
  FinanceFilterValue build() => (provider: null, type: null, status: null);

  void setProvider(String? v) => state = (provider: v, type: state.type, status: state.status);
  void setType(String? v) => state = (provider: state.provider, type: v, status: state.status);
  void setStatus(String? v) => state = (provider: state.provider, type: state.type, status: v);
  void clear() => state = build();
}

final financeFiltersProvider = NotifierProvider.autoDispose<FinanceFilters, FinanceFilterValue>(FinanceFilters.new);

final financeSummaryProvider = FutureProvider.autoDispose.family<FinanceSummary, MoneyRange>((ref, range) async {
  requireActive(ref);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get(
        Endpoints.financeSummary,
        query: ApiQuery.utcDays(from: range.from, to: range.to),
        decode: (d) => FinanceSummary.fromJson(JsonRead.object(d)),
        cancelToken: cancel,
      );
});

/// Paged GET /v1/finance/transactions for one range + filter set; [loadMore] appends the next page.
final class FinanceTransactionsPaged extends AsyncNotifier<Paged<FinanceTransaction>> {
  FinanceTransactionsPaged(this.query);

  final FinanceQuery query;
  bool _loadingMore = false;

  Future<Paged<FinanceTransaction>> _fetch(int page, {CancelToken? cancel}) {
    return ref.read(apiClientProvider).getPage(
      Endpoints.financeTransactions,
      FinanceTransaction.fromJson,
      query: {
        ...ApiQuery.utcDays(from: query.from, to: query.to),
        'provider': query.provider,
        'type': query.type,
        'status': query.status,
        ...ApiQuery.page(page),
      },
      cancelToken: cancel,
    );
  }

  @override
  Future<Paged<FinanceTransaction>> build() async {
    requireActive(ref);
    ref.watch(apiClientProvider);
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    return _fetch(1, cancel: cancel);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (_loadingMore || current == null || !current.hasMore || state.isLoading) return;
    _loadingMore = true;
    try {
      final next = await _fetch(current.meta.page + 1);
      if (!ref.mounted) return;
      state = AsyncData(current.append(next));
    } catch (_) {
      // A fresh instance lets the list request the page again on the next scroll.
      if (ref.mounted) state = AsyncData(Paged(items: current.items, meta: current.meta));
      rethrow;
    } finally {
      _loadingMore = false;
    }
  }
}

final financeTransactionsProvider =
    AsyncNotifierProvider.autoDispose.family<FinanceTransactionsPaged, Paged<FinanceTransaction>, FinanceQuery>(
  FinanceTransactionsPaged.new,
);

final class PayrollRange extends Notifier<DateRangeValue> {
  @override
  DateRangeValue build() => PeriodPreset.month.range(bizToday(ref.read(clockProvider), ref.watch(activeBusinessProvider)));

  void set(DateRangeValue value) => state = value;
}

final payrollRangeProvider = NotifierProvider.autoDispose<PayrollRange, DateRangeValue>(PayrollRange.new);

final payrollProvider = FutureProvider.autoDispose.family<PayrollReport, MoneyRange>((ref, range) async {
  requireActive(ref);
  ref.watch(staffRevisionProvider);
  ref.watch(appointmentsRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).get(
        Endpoints.payroll,
        query: ApiQuery.utcDays(from: range.from, to: range.to),
        decode: (d) => PayrollReport.fromJson(JsonRead.object(d)),
        cancelToken: cancel,
      );
});
