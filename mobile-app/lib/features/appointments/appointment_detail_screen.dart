import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/appointments/actions.dart';
import 'package:tizbiz_biznes/features/appointments/providers.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/info_row.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// One appointment: details, status actions and the Payme deposit link (BIZNES-SPEC §9.4).
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final int appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _busy = false;

  int get _id => widget.appointmentId;

  Future<void> _setStatus(Appointment ap, AppointmentStatus next) async {
    final destructive = next == AppointmentStatus.canceled || next == AppointmentStatus.noShow;
    if (destructive) {
      final ok = await confirmAction(
        context,
        title: next == AppointmentStatus.canceled ? 'Yozuv bekor qilinsinmi?' : 'Mijoz kelmadi deb belgilansinmi?',
        message: 'Bu amalni ortga qaytarib bo\'lmaydi.',
        confirmLabel: next.actionLabel,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(appointmentActionsProvider).setStatus(ap.id, next);
      if (!mounted) return;
      showAppSnack(context, 'Holat yangilandi');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message, error: true);
      if (e.isConflict) ref.invalidate(appointmentDetailProvider(_id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deposit(Appointment ap) async {
    setState(() => _busy = true);
    DepositCheckout? checkout;
    try {
      checkout = await ref.read(appointmentActionsProvider).depositLink(ap.id);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final url = checkout?.checkoutUrl;
    if (!mounted || checkout == null) return;
    if (url == null) {
      showAppSnack(context, "To'lov havolasi olinmadi.", error: true);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _DepositSheet(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(appointmentDetailProvider(_id));
    return Scaffold(
      appBar: AppBar(title: Text('Yozuv #$_id')),
      body: _isNotFound(value)
          ? const NotFoundText('Yozuv topilmadi')
          : AsyncBody<Appointment>(
              value: value,
              onRetry: () => ref.invalidate(appointmentDetailProvider(_id)),
              loading: const Center(child: CircularProgressIndicator()),
              data: (ap) => RefreshIndicator(
                onRefresh: () => ref.refresh(appointmentDetailProvider(_id).future),
                child: _Body(
                  appointment: ap,
                  busy: _busy,
                  onStatus: (s) => _setStatus(ap, s),
                  onDeposit: () => _deposit(ap),
                ),
              ),
            ),
    );
  }
}

bool _isNotFound(AsyncValue<Object?> v) {
  final e = v.error;
  return !v.hasValue && e is ApiException && e.isNotFound;
}

/// Centered "not found" text for a detail screen whose row is gone (404).
class NotFoundText extends StatelessWidget {
  const NotFoundText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.of(context).textMuted),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.appointment, required this.busy, required this.onStatus, required this.onDeposit});

  final Appointment appointment;
  final bool busy;
  final ValueChanged<AppointmentStatus> onStatus;
  final VoidCallback onDeposit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final ap = appointment;
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final tz = a?.timezone ?? Dates.defaultTimezone;
    final start = ap.startLocal(tz);
    final rental = a?.engine == Engine.rental;
    final canClients = a?.can(Permissions.clients) ?? false;
    final next = ap.status.adminNext;
    return MaxWidth(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [AppointmentStatusBadge(ap.status)]),
          const SizedBox(height: 8),
          Text(UzDates.weekdayDayMonth(start.date), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(UzDates.timeRange(start, ap.endLocal(tz)), style: t.titleMedium),
          if (rental && a != null)
            Text(
              [rentalSessionLabel(ap, a), if ((ap.guests ?? 0) > 0) '${ap.guests} mehmon'].join(' · '),
              style: t.bodyMedium?.copyWith(color: c.textMuted),
            ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Mijoz',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((ap.clientName ?? '').isEmpty ? '—' : ap.clientName!, style: t.titleSmall),
                if ((ap.clientPhone ?? '').isNotEmpty) PhoneLink(ap.clientPhone),
                if (ap.clientId != null && canClients)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => unawaited(context.push(Routes.client(ap.clientId!))),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Mijoz kartasi'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: rental ? 'Buyum / zal' : 'Xizmat',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: 'Nomi', value: Text(ap.serviceName ?? '—')),
                if (ap.serviceDuration != null)
                  InfoRow(label: 'Davomiyligi', value: Text(UzDates.duration(ap.serviceDuration!))),
                InfoRow(label: 'Xodim', value: Text(ap.staffName ?? '—')),
                InfoRow(label: 'Manba', value: Text(sourceLabel(ap.source))),
              ],
            ),
          ),
          if ((ap.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(title: 'Izoh', child: Text(ap.notes!.trim())),
          ],
          if (ap.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: "Qo'shimchalar",
              child: Column(
                children: [
                  for (final i in ap.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(i.name)),
                          Text(
                            '${i.qty} × ${Money.format(i.priceTiyin)} = ${Money.format(i.totalTiyin)}',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if ((ap.depositTiyin ?? 0) > 0) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: "To'lov",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoRow(label: 'Depozit', value: Text(Money.format(ap.depositTiyin))),
                  InfoRow(
                    label: 'Holati',
                    value: Text(
                      ap.paid ? "To'langan" : "To'lanmagan",
                      style: TextStyle(color: ap.paid ? c.success : c.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (ap.requiresDeposit && ap.status.isLive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onDeposit,
                        icon: const Icon(Icons.link),
                        label: const Text("To'lov havolasi (Payme)"),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (next.isEmpty)
            Text(
              'Bu yozuv yakunlangan',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: c.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, s) in next.indexed)
                  if (s == AppointmentStatus.canceled || s == AppointmentStatus.noShow)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.danger,
                        side: BorderSide(color: c.danger),
                      ),
                      onPressed: busy ? null : () => onStatus(s),
                      child: Text(s.actionLabel),
                    )
                  else if (i == 0)
                    FilledButton(onPressed: busy ? null : () => onStatus(s), child: Text(s.actionLabel))
                  else
                    FilledButton.tonal(onPressed: busy ? null : () => onStatus(s), child: Text(s.actionLabel)),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            "Vaqtni o'zgartirish uchun yozuvni bekor qilib, yangisini yarating.",
            style: t.bodySmall?.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DepositSheet extends StatelessWidget {
  const _DepositSheet({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Payme to'lov havolasi", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(url.toString(), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
              if (!ok && context.mounted) showAppSnack(context, "Havolani ochib bo'lmadi.", error: true);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Ochish'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url.toString()));
              if (context.mounted) showAppSnack(context, 'Havola nusxalandi');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Nusxalash'),
          ),
        ],
      ),
    ),
  );
}
