import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/money/actions.dart';
import 'package:tizbiz_biznes/features/money/providers.dart';
import 'package:tizbiz_biznes/features/money/widgets/commission_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/period_chips.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const _formulaNote =
    'Ish haqi = tushum × komissiya %; tushum yakunlangan yozuvlarning xizmat narxlari bo\'yicha.';
const _rentalNote = "Ijara daromadi mehmonlar soniga ko'paytirilmagan (xizmat narxi bo'yicha).";

/// Ish haqi (BIZNES-SPEC §9.9).
class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  Future<void> _editCommission(BuildContext context, WidgetRef ref, PayrollRow row) async {
    final saved = await CommissionDialog.show(
      context,
      staffName: row.name,
      initial: row.commissionPercent,
      onSubmit: (p) => ref.read(moneyActionsProvider).setCommission(row.staffId, p),
    );
    if (saved == true && context.mounted) showAppSnack(context, 'Komissiya saqlandi');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final range = ref.watch(payrollRangeProvider);
    final value = ref.watch(payrollProvider(range.key));
    final rental = ref.watch(activeBusinessProvider)?.engine == Engine.rental;
    final muted = TextStyle(fontSize: 12, color: c.textMuted);
    return Scaffold(
      appBar: AppBar(title: const Text('Ish haqi')),
      body: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            PeriodChips(
              value: range,
              presets: const [PeriodPreset.month, PeriodPreset.prevMonth, PeriodPreset.custom],
              onChanged: ref.read(payrollRangeProvider.notifier).set,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AsyncBody<PayrollReport>(
                value: value,
                onRetry: () => ref.invalidate(payrollProvider(range.key)),
                isEmpty: (r) => r.staff.isEmpty,
                empty: RefreshIndicator(
                  onRefresh: () => ref.refresh(payrollProvider(range.key).future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyView(icon: Icons.groups_outlined, title: "Faol xodimlar yo'q"),
                    ],
                  ),
                ),
                data: (r) => RefreshIndicator(
                  onRefresh: () => ref.refresh(payrollProvider(range.key).future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      SectionCard(
                        child: Row(
                          children: [
                            Expanded(child: _Total(label: 'Jami tushum', tiyin: r.totalRevenueTiyin)),
                            Expanded(child: _Total(label: 'Jami ish haqi', tiyin: r.totalEarningsTiyin, bold: true)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < r.staff.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _PayrollTile(row: r.staff[i], onCommission: () => _editCommission(context, ref, r.staff[i])),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_formulaNote, style: muted),
                      if (rental) ...[const SizedBox(height: 6), Text(_rentalNote, style: muted)],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.tiyin, this.bold = false});

  final String label;
  final int tiyin;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.format(tiyin),
            style: TextStyle(fontSize: 18, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PayrollTile extends StatelessWidget {
  const _PayrollTile({required this.row, required this.onCommission});

  final PayrollRow row;
  final VoidCallback onCommission;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${row.appointments} ta yakunlangan · tushum ${Money.format(row.revenueTiyin)}',
                    style: TextStyle(fontSize: 12, color: c.textMuted)),
                const SizedBox(height: 4),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text('Komissiya ${row.commissionPercent}%'),
                  onPressed: onCommission,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(Money.format(row.earningsTiyin), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
