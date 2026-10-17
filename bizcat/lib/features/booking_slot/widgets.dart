import 'dart:async';

import 'package:bizcat/core/errors.dart';
import 'package:bizcat/features/booking_slot/providers.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Muted section label above a step's content.
class SlotStepLabel extends StatelessWidget {
  const SlotStepLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: BzSpace.m),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// A tappable card with a primary border when [selected].
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(BzRadius.l);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? scheme.primary : scheme.outline, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(BzSpace.l), child: child),
      ),
    );
  }
}

/// Service card: name, duration, price and a deposit chip.
class SlotServiceCard extends StatelessWidget {
  const SlotServiceCard({super.key, required this.service, required this.selected, required this.onTap});

  final Service service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: theme.textTheme.titleMedium),
                if (service.description != null) ...[
                  const SizedBox(height: BzSpace.xs),
                  Text(service.description!, style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: BzSpace.s),
                Wrap(
                  spacing: BzSpace.m,
                  runSpacing: BzSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: BzSpace.xs),
                        Text(UzDates.duration(service.durationMin), style: muted),
                      ],
                    ),
                    Text(
                      Money.format(service.priceTiyin),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (service.requiresDeposit) ...[
                  const SizedBox(height: BzSpace.s),
                  _DepositChip(depositTiyin: service.depositTiyin!),
                ],
              ],
            ),
          ),
          const SizedBox(width: BzSpace.s),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _DepositChip extends StatelessWidget {
  const _DepositChip({required this.depositTiyin});

  final int depositTiyin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BzSpace.s, vertical: BzSpace.xs),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(BzRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: BzSpace.xs),
          Flexible(
            child: Text(
              "Oldindan to'lov: ${Money.format(depositTiyin)}",
              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff card: initials logo, name, specialization.
class SlotStaffCard extends StatelessWidget {
  const SlotStaffCard({super.key, required this.staff, required this.selected, required this.onTap});

  final Staff staff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          BizLogo(name: staff.name, size: 48),
          const SizedBox(width: BzSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name, style: theme.textTheme.titleMedium),
                if (staff.specialization != null)
                  Text(
                    staff.specialization!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Horizontal strip of [kSlotDayStrip] days starting at [today].
class SlotDayStrip extends StatefulWidget {
  const SlotDayStrip({super.key, required this.today, required this.selected, required this.onPick});

  final LocalDate today;
  final LocalDate selected;
  final ValueChanged<LocalDate> onPick;

  @override
  State<SlotDayStrip> createState() => _SlotDayStripState();
}

class _SlotDayStripState extends State<SlotDayStrip> {
  static const double _chipWidth = 64;
  static const double _gap = BzSpace.s;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(SlotDayStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: true));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the selected chip in view.
  void _reveal({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final index = widget.today.daysUntil(widget.selected);
    if (index < 0) return;
    final pos = _scroll.position;
    final start = index * (_chipWidth + _gap);
    final end = start + _chipWidth;
    double? target;
    if (start < pos.pixels) {
      target = start;
    } else if (end > pos.pixels + pos.viewportDimension) {
      target = end - pos.viewportDimension;
    }
    if (target == null) return;
    final clamped = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (animate) {
      unawaited(_scroll.animateTo(clamped, duration: const Duration(milliseconds: 250), curve: Curves.easeOut));
    } else {
      _scroll.jumpTo(clamped);
    }
  }

  String _topLabel(LocalDate d) {
    final diff = widget.today.daysUntil(d);
    if (diff == 0) return 'Bugun';
    if (diff == 1) return 'Ertaga';
    return UzDates.weekdayShort(d.weekday);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
        itemCount: kSlotDayStrip,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final d = widget.today.addDays(i);
          final selected = d == widget.selected;
          final fg = selected ? scheme.onPrimary : scheme.onSurface;
          final mutedFg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
          return Semantics(
            button: true,
            selected: selected,
            label: '${_topLabel(d)}, ${UzDates.dayMonth(d)}',
            excludeSemantics: true,
            child: Material(
              key: ValueKey('slot-day-${d.toIso()}'),
              color: selected ? scheme.primary : scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BzRadius.m),
                side: BorderSide(color: selected ? scheme.primary : scheme.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onPick(d),
                child: SizedBox(
                  width: _chipWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_topLabel(d), style: theme.textTheme.labelSmall?.copyWith(color: mutedFg)),
                      const SizedBox(height: 2),
                      Text('${d.day}', style: BzText.sora(context, 20, color: fg)),
                      const SizedBox(height: 2),
                      Text(UzDates.monthShort(d.month), style: theme.textTheme.labelSmall?.copyWith(color: mutedFg)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const List<(String, String)> _buckets = [
  ('morning', 'Ertalab'),
  ('afternoon', 'Kunduzi'),
  ('evening', 'Kechqurun'),
];

/// `Bo'sh vaqtlar` for the current service/staff/date, grouped by part of day.
class SlotTimes extends ConsumerWidget {
  const SlotTimes({
    super.key,
    required this.availabilityKey,
    required this.selected,
    required this.onPick,
    this.onNextDay,
  });

  final ({int staffId, int serviceId, LocalDate date}) availabilityKey;
  final AvailabilitySlot? selected;
  final ValueChanged<AvailabilitySlot> onPick;

  /// Null when the next day is outside the strip.
  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = ref.watch(slotAvailabilityProvider(availabilityKey));
    final Widget body;
    if (value.isLoading || (!value.hasValue && !value.hasError)) {
      body = const _SlotSkeleton();
    } else if (value.hasError) {
      final e = value.error!;
      body = isOffline(e)
          ? OfflineState(onRetry: () => ref.invalidate(slotAvailabilityProvider(availabilityKey)))
          : ErrorState(
              message: errorText(e),
              onRetry: () => ref.invalidate(slotAvailabilityProvider(availabilityKey)),
            );
    } else {
      final slots = value.requireValue.slots;
      if (slots.isEmpty) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bu kunga bo'sh vaqt yo'q. Boshqa kunni tanlang.",
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (onNextDay != null) ...[
              const SizedBox(height: BzSpace.m),
              SecondaryButton(
                label: 'Keyingi kun',
                icon: Icons.arrow_forward,
                expanded: false,
                onPressed: onNextDay,
              ),
            ],
          ],
        );
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (key, label) in _buckets)
              if (slots.where((s) => s.bucket == key).toList() case final group when group.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: BzSpace.s, bottom: BzSpace.s),
                  child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Wrap(
                  spacing: BzSpace.s,
                  runSpacing: BzSpace.s,
                  children: [
                    for (final s in group)
                      _TimeChip(
                        slot: s,
                        selected: selected != null && selected!.startUtc.isAtSameMomentAs(s.startUtc),
                        onTap: () => onPick(s),
                      ),
                  ],
                ),
                const SizedBox(height: BzSpace.s),
              ],
          ],
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SlotStepLabel("Bo'sh vaqtlar"),
        body,
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.slot, required this.selected, required this.onTap});

  final AvailabilitySlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = slot.startLocal.format();
    return Material(
      key: ValueKey('slot-time-$text'),
      color: selected ? scheme.primary : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BzRadius.m),
        side: BorderSide(color: selected ? scheme.primary : scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 44,
          alignment: Alignment.center,
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 8 static skeleton chips while the slots load.
class _SlotSkeleton extends StatelessWidget {
  const _SlotSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Semantics(
      label: 'Yuklanmoqda...',
      child: Wrap(
        spacing: BzSpace.s,
        runSpacing: BzSpace.s,
        children: [
          for (var i = 0; i < 8; i++)
            Container(
              width: 76,
              height: 44,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(BzRadius.m)),
            ),
        ],
      ),
    );
  }
}

/// The error box under the confirm form (and above the slots after a 400).
class SlotAlert extends StatelessWidget {
  const SlotAlert({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BzSpace.l),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(BzRadius.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                const SizedBox(width: BzSpace.s),
                Expanded(
                  child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: BzSpace.m), action!],
          ],
        ),
      ),
    );
  }
}
