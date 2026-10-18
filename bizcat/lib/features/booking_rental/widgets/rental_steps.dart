import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// A step label (`To'y vaqtini tanlang`).
class RentalStepLabel extends StatelessWidget {
  const RentalStepLabel(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: theme.textTheme.titleLarge),
        if (hint != null) ...[
          const SizedBox(height: BzSpace.xs),
          Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// One session card: icon, title, subtitle, per-guest price.
class RentalSessionCard extends StatelessWidget {
  const RentalSessionCard({super.key, required this.session, required this.selected, required this.onTap});

  final RentalSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = session == RentalSession.morning ? BzIcons.sun : BzIcons.moon;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BzRadius.l),
          side: BorderSide(color: selected ? scheme.primary : scheme.outline, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(BzSpace.l),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: BzSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(RentalPricing.title(session), style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        RentalPricing.subtitle(session),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BzSpace.s),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Money.format(RentalPricing.perGuestTiyin(session)),
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                    Text('/ kishi', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `−` / numeric field / `+` (±[RentalPricing.guestStep]).
class GuestStepper extends StatelessWidget {
  const GuestStepper({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.value,
    required this.onStep,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int value;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Kamaytirish',
          iconSize: 24,
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          onPressed: value > RentalPricing.minGuests ? () => onStep(-RentalPricing.guestStep) : null,
          icon: const Icon(BzIcons.remove),
        ),
        const SizedBox(width: BzSpace.m),
        Expanded(
          child: TextField(
            key: const ValueKey('rental-guests-field'),
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            style: BzText.sora(context, 24),
            decoration: const InputDecoration(suffixText: 'kishi'),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        const SizedBox(width: BzSpace.m),
        IconButton.outlined(
          tooltip: "Ko'paytirish",
          iconSize: 24,
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          onPressed: value < RentalPricing.maxGuests ? () => onStep(RentalPricing.guestStep) : null,
          icon: const Icon(BzIcons.add),
        ),
      ],
    );
  }
}

/// The guests summary: tables, per guest, total.
class GuestSummaryCard extends StatelessWidget {
  const GuestSummaryCard({super.key, required this.session, required this.guests});

  final RentalSession session;
  final int guests;

  @override
  Widget build(BuildContext context) => SummaryCard(
    rows: [
      SummaryRow(label: 'Stollar soni', value: '${RentalPricing.tables(guests)} ta stol'),
      SummaryRow(label: 'Bir kishiga', value: Money.format(RentalPricing.perGuestTiyin(session))),
      SummaryRow(
        label: 'Jami taxminan',
        value: Money.format(RentalPricing.totalTiyin(session, guests)),
        emphasize: true,
      ),
    ],
  );
}

/// A tinted alert box (submit errors on the confirm step).
class RentalAlert extends StatelessWidget {
  const RentalAlert({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(BzSpace.l),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(BzRadius.m)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(BzIcons.danger, color: scheme.onErrorContainer, size: 20),
              const SizedBox(width: BzSpace.s),
              Expanded(
                child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: BzSpace.m), action!],
        ],
      ),
    );
  }
}
