import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/money/providers.dart';
import 'package:tizbiz_biznes/features/money/widgets/finance_filters.dart';
import 'package:tizbiz_biznes/features/money/widgets/transaction_tile.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/kpi_card.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/paged_list_view.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Moliya (BIZNES-SPEC §9.9).
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(financeRangeProvider);
    final f = ref.watch(financeFiltersProvider);
    final FinanceQuery query = (from: range.from, to: range.to, provider: f.provider, type: f.type, status: f.status);
    final tx = ref.watch(financeTransactionsProvider(query));
    // Start the summary in parallel with the first page (it renders in the list header).
    ref.listen(financeSummaryProvider(range.key), (_, _) {});

    Future<void> refresh() async {
      await Future.wait<Object?>([
        ref.refresh(financeSummaryProvider(range.key).future).then<Object?>((v) => v, onError: (Object _) => null),
        ref.refresh(financeTransactionsProvider(query).future).then<Object?>((v) => v, onError: (Object _) => null),
      ]);
    }

    Future<void> loadMore() async {
      try {
        await ref.read(financeTransactionsProvider(query).notifier).loadMore();
      } catch (e) {
        if (context.mounted) showAppSnack(context, errorText(e), error: true);
      }
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummarySection(range: range.key),
        const SizedBox(height: 8),
        const FinanceFilterChips(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text('Sanalar UTC kunlari bo\'yicha.',
              style: TextStyle(fontSize: 12, color: AppColors.of(context).textMuted)),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Moliya')),
      body: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            PeriodChips(
              value: range,
              presets: const [PeriodPreset.last7, PeriodPreset.last30, PeriodPreset.last90, PeriodPreset.custom],
              onChanged: ref.read(financeRangeProvider.notifier).set,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AsyncBody<Paged<FinanceTransaction>>(
                value: tx,
                onRetry: () => ref.invalidate(financeTransactionsProvider(query)),
                loading: const SkeletonList(),
                data: (page) => PagedListView<FinanceTransaction>(
                  page: page,
                  header: page.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            header,
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: EmptyView(icon: Icons.receipt_long_outlined, title: "Bu davrda to'lovlar yo'q"),
                            ),
                          ],
                        )
                      : header,
                  separator: const Divider(height: 1, indent: 72),
                  onLoadMore: loadMore,
                  onRefresh: refresh,
                  itemBuilder: (context, t) => TransactionTile(tx: t),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.range});

  final MoneyRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final value = ref.watch(financeSummaryProvider(range));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncBody<FinanceSummary>(
        value: value,
        expand: false,
        onRetry: () => ref.invalidate(financeSummaryProvider(range)),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 112,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                KpiCard(label: 'Kirim', value: Money.format(s.incomeTiyin), tone: c.success),
                KpiCard(label: 'Qaytarishlar', value: Money.format(s.refundsTiyin), tone: c.danger),
                KpiCard(label: 'Sof', value: Money.format(s.netTiyin)),
                KpiCard(label: 'Tranzaksiyalar', value: '${s.count}'),
              ],
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: "To'lov tizimlari",
              child: s.byProvider.isEmpty
                  ? Text("To'lovlar yo'q", style: TextStyle(color: c.textMuted))
                  : Column(
                      children: [
                        for (final p in s.byProvider)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(providerLabel(p.provider))),
                                Text('${p.count} ta', style: TextStyle(color: c.textMuted, fontSize: 12)),
                                const SizedBox(width: 12),
                                Text(Money.format(p.amountTiyin), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
