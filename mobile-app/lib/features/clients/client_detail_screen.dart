import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/clients/actions.dart';
import 'package:tizbiz_biznes/features/clients/providers.dart';
import 'package:tizbiz_biznes/features/clients/widgets/categories_editor.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_link.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_biznes/shared/widgets/status_badge.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Client card: contacts, loyalty, categories and the visit history (BIZNES-SPEC §9.6).
class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool _deleting = false;

  int get _id => widget.clientId;

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: "Mijoz o'chirilsinmi? Tarixi saqlanadi.",
      confirmLabel: "O'chirish",
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(clientActionsProvider).delete(_id);
      if (!mounted) return;
      showAppSnack(context, "Mijoz o'chirildi");
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.clients);
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(clientDetailProvider(_id));
    final e = value.error;
    final notFound = !value.hasValue && e is ApiException && e.isNotFound;
    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.client.name ?? 'Mijoz'),
        actions: [
          if (value.hasValue) ...[
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => unawaited(context.push(Routes.clientEdit(_id))),
            ),
            IconButton(
              tooltip: "O'chirish",
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
          ],
        ],
      ),
      body: notFound
          ? const Center(child: Text('Mijoz topilmadi'))
          : AsyncBody<ClientDetail>(
              value: value,
              loading: const Center(child: CircularProgressIndicator()),
              onRetry: () => ref.invalidate(clientDetailProvider(_id)),
              data: (d) => RefreshIndicator(
                onRefresh: () => ref.refresh(clientDetailProvider(_id).future),
                child: _Body(detail: d),
              ),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final ClientDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(activeBusinessProvider);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final cl = detail.client;
    final tz = a?.timezone ?? Dates.defaultTimezone;
    final today = bizToday(ref.read(clockProvider), a);
    final loyalty = detail.loyalty;
    return MaxWidth(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(cl.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          PhoneLink(cl.phone),
          if (cl.email != null) Text(cl.email!, style: t.bodyMedium),
          if (cl.birthday != null) Text("Tug'ilgan kun: ${UzDates.dayMonthYear(cl.birthday!)}", style: t.bodyMedium),
          if (cl.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final tag in cl.tags) Chip(label: Text(tag), visualDensity: VisualDensity.compact)],
              ),
            ),
          if ((cl.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(cl.notes!.trim(), style: t.bodyMedium?.copyWith(color: c.textMuted)),
            ),
          if (a?.hasAppointments ?? false) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => unawaited(context.push(Routes.appointmentNew(clientId: cl.id))),
                icon: const Icon(Icons.add),
                label: const Text('Yangi yozuv'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Loyallik',
            child: loyalty == null
                ? Text("Loyallik hisobi yo'q", style: t.bodyMedium?.copyWith(color: c.textMuted))
                : Row(
                    children: [
                      Expanded(
                        child: _Stat(label: 'Ballar', value: '${loyalty.points}'),
                      ),
                      Expanded(
                        child: _Stat(label: 'Keshbek', value: Money.format(loyalty.cashbackTiyin)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Kategoriyalar',
            child: CategoriesEditor(clientId: cl.id, selected: detail.categories),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Tashriflar tarixi',
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: detail.history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text("Tashriflar yo'q", style: t.bodyMedium?.copyWith(color: c.textMuted)),
                  )
                : Column(
                    children: [
                      for (final h in detail.history)
                        ListTile(
                          onTap: () => unawaited(context.push(Routes.appointment(h.id))),
                          title: Text(h.serviceName ?? 'Xizmat'),
                          subtitle: Text(
                            [
                              UzDates.dateTime(h.startLocal(tz), today: today),
                              if ((h.staffName ?? '').isNotEmpty) h.staffName!,
                            ].join(' · '),
                          ),
                          trailing: AppointmentStatusBadge(h.status),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.bodySmall?.copyWith(color: AppColors.of(context).textMuted)),
        Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
