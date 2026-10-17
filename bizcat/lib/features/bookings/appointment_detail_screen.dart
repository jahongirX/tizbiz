import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/features/bookings/providers.dart';
import 'package:bizcat/features/bookings/widgets.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/location_card.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/poller.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Reason chips of the cancel sheet.
const List<String> kCancelReasons = ['Rejam o\'zgardi', 'Boshqa vaqtga yozilaman', 'Boshqa sabab'];

/// One appointment: status, summary, the deposit (Payme), location and the actions.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.id, this.justCreated = false});

  final int id;
  final bool justCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(appointmentDetailProvider(id));
    void retry() => ref.invalidate(appointmentDetailProvider(id));

    final Widget body;
    final a = value.value;
    if (a != null) {
      body = _AppointmentBody(appointment: a, justCreated: justCreated);
    } else if (value.hasError && !value.isLoading) {
      final e = value.error!;
      if (e is ApiException && e.isNotFound) {
        body = EmptyState(
          icon: Icons.event_busy,
          title: 'Bron topilmadi',
          message: "Bu bron o'chirilgan yoki sizga tegishli emas.",
          actionLabel: 'Bronlarim',
          onAction: () => context.go(AppRoutes.bookings),
        );
      } else if (isOffline(e)) {
        body = OfflineState(onRetry: retry);
      } else {
        body = ErrorState(message: errorText(e), onRetry: retry);
      }
    } else {
      // Scroll-wrapped so the skeleton never overflows short or wide screens.
      body = const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: LoadingView(kind: LoadingKind.detail, rows: 3),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => popOrGo(context, AppRoutes.bookings)),
        title: Text('Bron #$id'),
      ),
      body: body,
      bottomNavigationBar: justCreated
          ? BottomActionBar(
              child: PrimaryButton(label: "Bronlarimga o'tish", onPressed: () => context.go(AppRoutes.bookings)),
            )
          : null,
    );
  }
}

class _AppointmentBody extends ConsumerWidget {
  const _AppointmentBody({required this.appointment, required this.justCreated});

  final Appointment appointment;
  final bool justCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = appointment;
    final b = a.business;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = bookingToday(b);
    final rental = isRentalAppointment(a);
    final ctrl = ref.read(appointmentDetailProvider(a.id).notifier);
    final live = a.status.isLive;
    final paidLive = depositPaid(a) && live;
    final phone = b?.phone;
    final hasPhone = Phone.telUri(phone) != null;

    return RefreshIndicator(
      onRefresh: () => ctrl.refresh(silent: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxl),
        children: [
          if (justCreated)
            SuccessHero(
              title: rental ? 'Bron qabul qilindi!' : 'Navbat band qilindi!',
              subtitle: UzDates.dateTime(a.startLocal(), today: today),
              note: a.status == AppointmentStatus.pending ? "Biznes tasdiqlashi bilan holat o'zgaradi." : null,
            ),
          BusinessBlock(business: b, chip: AppointmentStatusChip(a.status)),
          const SizedBox(height: BzSpace.m),
          SummaryCard(rows: appointmentSummaryRows(a)),
          if (a.requiresDeposit &&
              (a.status == AppointmentStatus.pending || a.status == AppointmentStatus.confirmed)) ...[
            const SizedBox(height: BzSpace.m),
            _DepositCallout(appointment: a),
          ] else if (depositPaid(a) && a.status != AppointmentStatus.canceled) ...[
            const SizedBox(height: BzSpace.m),
            const InfoLine(
              icon: Icons.verified_outlined,
              text: "Oldindan to'lov qilingan",
              foreground: BzColors.success,
              background: BzColors.successBg,
            ),
          ],
          if (b != null) ...[
            const SizedBox(height: BzSpace.m),
            LocationCard(address: b.address, mapUrl: b.mapUrl, name: b.name, phone: b.phone),
          ],
          if (hasPhone) ...[
            const SizedBox(height: BzSpace.m),
            PrimaryButton(
              label: "Qo'ng'iroq qilish",
              icon: Icons.call,
              onPressed: () => unawaited(callPhone(ref, phone)),
            ),
          ],
          if (a.canReview ?? false) ...[
            const SizedBox(height: BzSpace.m),
            PrimaryButton(
              label: 'Sharh qoldirish',
              icon: Icons.rate_review_outlined,
              onPressed: () => unawaited(context.push(AppRoutes.reviewNew(appointmentId: a.id, businessName: b?.name))),
            ),
          ] else if (a.reviewId != null) ...[
            const SizedBox(height: BzSpace.m),
            SecondaryButton(
              label: 'Sharhim',
              icon: Icons.rate_review_outlined,
              onPressed: () => unawaited(context.push(AppRoutes.myReviews)),
            ),
          ],
          if (a.canCancel ?? false) ...[
            const SizedBox(height: BzSpace.l),
            Center(
              child: DangerTextButton(
                label: 'Bronni bekor qilish',
                onPressed: () => unawaited(_cancel(context, ref, a.id)),
              ),
            ),
          ] else if (paidLive) ...[
            const SizedBox(height: BzSpace.l),
            Text(
              "Oldindan to'lov qilingan bronni bekor qilish uchun biznes bilan bog'laning.",
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _cancel(BuildContext context, WidgetRef ref, int id) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CancelSheet(),
    );
    if (reason == null) return;
    final ok = await ref.read(appointmentDetailProvider(id).notifier).cancel(reason: reason);
    if (ok) showSnack('Bron bekor qilindi.');
  }
}

/// The summary rows (slot: service, staff, date, time, price; rental: session, guests, estimate).
List<SummaryRow> appointmentSummaryRows(Appointment a) {
  final tz = bookingTimezone(a.business);
  final start = a.startLocal();
  final today = bookingToday(a.business);
  final rows = <SummaryRow>[if ((a.serviceName ?? '').isNotEmpty) SummaryRow(label: 'Xizmat', value: a.serviceName!)];
  if (isRentalAppointment(a)) {
    final session = RentalPricing.sessionOf(a, tz);
    final guests = a.guests ?? 0;
    rows
      ..add(
        SummaryRow(
          label: 'Sana',
          value: UzDates.dayLabel(start.date, today: today),
        ),
      )
      ..add(
        SummaryRow(
          label: 'Vaqt',
          value: session == null
              ? UzDates.timeRange(start, a.endLocal())
              : '${RentalPricing.title(session)} · ${RentalPricing.hours(session)}',
        ),
      );
    if (guests > 0) {
      rows.add(SummaryRow(label: 'Mehmonlar', value: '$guests kishi · ${RentalPricing.tables(guests)} stol'));
      if (session != null) {
        rows.add(
          SummaryRow(
            label: 'Jami taxminan',
            value: Money.format(RentalPricing.totalTiyin(session, guests)),
            emphasize: true,
          ),
        );
      }
    }
  } else {
    rows
      ..addAll([
        if ((a.staffName ?? '').isNotEmpty) SummaryRow(label: 'Mutaxassis', value: a.staffName!),
        SummaryRow(
          label: 'Sana',
          value: UzDates.dayLabel(start.date, today: today),
        ),
        SummaryRow(label: 'Vaqt', value: UzDates.timeRange(start, a.endLocal())),
      ])
      ..addAll([
        if ((a.servicePriceTiyin ?? 0) > 0)
          SummaryRow(label: 'Narxi', value: Money.format(a.servicePriceTiyin), emphasize: true),
      ]);
  }
  final notes = a.notes?.trim() ?? '';
  if (notes.isNotEmpty) rows.add(SummaryRow(label: 'Izoh', value: notes));
  return rows;
}

/// The unpaid deposit card: amount, the Payme CTA and the 5 s poll while awaiting the payment.
class _DepositCallout extends ConsumerStatefulWidget {
  const _DepositCallout({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_DepositCallout> createState() => _DepositCalloutState();
}

class _DepositCalloutState extends ConsumerState<_DepositCallout> {
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    await ref.read(appointmentDetailProvider(widget.appointment.id).notifier).payDeposit();
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final theme = Theme.of(context);
    final watch = ref.watch(depositWatchProvider(a.id));
    final ctrl = ref.read(appointmentDetailProvider(a.id).notifier);
    const fg = BzColors.warning;

    return Poller(
      interval: DepositWatch.interval,
      enabled: watch.awaitingPayment,
      refreshOnResume: true,
      onTick: () => unawaited(ctrl.pollDeposit()),
      child: Container(
        padding: const EdgeInsets.all(BzSpace.l),
        decoration: BoxDecoration(color: BzColors.warningBg, borderRadius: BorderRadius.circular(BzRadius.m)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: fg),
                const SizedBox(width: BzSpace.s),
                Expanded(
                  child: Text(
                    "Oldindan to'lov: ${Money.format(a.depositTiyin)}",
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BzSpace.s),
            Text(
              "Joyingizni kafolatlash uchun oldindan to'lov qiling. To'lov ixtiyoriy.",
              style: theme.textTheme.bodyMedium?.copyWith(color: BzColors.indigo),
            ),
            const SizedBox(height: BzSpace.m),
            if (watch.awaitingPayment) ...[
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                  const SizedBox(width: BzSpace.s),
                  Expanded(
                    child: Text(
                      "To'lov tasdiqlanishi kutilmoqda...",
                      style: theme.textTheme.bodyMedium?.copyWith(color: BzColors.indigo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BzSpace.m),
            ] else if (watch.timedOut) ...[
              Text(
                "To'lov hali tasdiqlanmadi. Keyinroq yangilang.",
                style: theme.textTheme.bodyMedium?.copyWith(color: BzColors.indigo),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => unawaited(ctrl.refresh(silent: false)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yangilash'),
                ),
              ),
              const SizedBox(height: BzSpace.s),
            ],
            CtaButton(
              label: "Payme orqali to'lash",
              icon: Icons.payment,
              loading: _paying,
              onPressed: _paying ? null : () => unawaited(_pay()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The cancel bottom sheet; pops with the reason text, or null when dismissed.
class CancelSheet extends StatefulWidget {
  const CancelSheet({super.key});

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  String? _reason;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _result {
    final t = _text.text.trim();
    if (_reason == kCancelReasons.last) return t.isEmpty ? _reason! : t;
    return _reason ?? t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BzSpace.gutter,
        0,
        BzSpace.gutter,
        BzSpace.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bronni bekor qilish', style: theme.textTheme.titleLarge),
            const SizedBox(height: BzSpace.m),
            Wrap(
              spacing: BzSpace.s,
              runSpacing: BzSpace.s,
              children: [
                for (final r in kCancelReasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    onSelected: (on) => setState(() => _reason = on ? r : null),
                  ),
              ],
            ),
            const SizedBox(height: BzSpace.m),
            TextField(
              controller: _text,
              maxLength: 200,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Izoh (ixtiyoriy)'),
            ),
            const SizedBox(height: BzSpace.s),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => Navigator.of(context).pop(_result),
              child: const Text('Bekor qilish'),
            ),
          ],
        ),
      ),
    );
  }
}
