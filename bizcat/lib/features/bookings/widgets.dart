import 'dart:async';
import 'dart:math' as math;

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The business timezone of a booking (fallback Asia/Tashkent).
String bookingTimezone(BusinessRef? b) => b?.timezone ?? Dates.defaultTimezone;

/// Today in the business timezone.
LocalDate bookingToday(BusinessRef? b) => Dates.todayLocal(timezone: bookingTimezone(b));

/// Whether the appointment belongs to a rental (hall) business.
bool isRentalAppointment(Appointment a) => a.business?.engine == Engine.rental;

/// The deposit was paid (there was one to pay).
bool depositPaid(Appointment a) => (a.depositTiyin ?? 0) > 0 && a.paid;

/// 'Ertalab' / 'Kechqurun' for a rental, else the time range.
String rentalSessionLabel(Appointment a) {
  final s = RentalPricing.sessionOf(a, bookingTimezone(a.business));
  if (s != null) return RentalPricing.title(s);
  return UzDates.timeRange(a.startLocal(), a.endLocal());
}

/// `Napoleon torti (1 kg) ×2 va yana 1`.
String orderItemsLabel(Order o) {
  if (o.items.isEmpty) return o.itemsCount > 0 ? '${o.itemsCount} ta mahsulot' : 'Buyurtma';
  final first = o.items.first;
  final more = math.max(o.itemsCount, o.items.length) - 1;
  return '${first.name} ×${first.qty}${more > 0 ? ' va yana $more' : ''}';
}

/// A small colored line with an icon (deposit states, info notes).
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
    this.dense = false,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = (dense ? Theme.of(context).textTheme.bodySmall : Theme.of(context).textTheme.bodyMedium)?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: BzSpace.m, vertical: dense ? 6 : BzSpace.m),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(BzRadius.s)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: dense ? 16 : 20, color: foreground),
          const SizedBox(width: BzSpace.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Logo + business name + status chip (top row of the list cards).
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.business, required this.chip});

  final BusinessRef? business;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = business?.name ?? '';
    return Row(
      children: [
        BizLogo(url: business?.logo, name: name, size: 32, brandColor: business?.brandColor),
        const SizedBox(width: BzSpace.s),
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: BzSpace.s),
        chip,
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ),
      ],
    );
  }
}

/// One appointment in "Bronlarim".
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, required this.past});

  final Appointment appointment;

  /// In the `O'tgan` tab (review / rebook actions).
  final bool past;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final b = a.business;
    final rental = isRentalAppointment(a);
    final subtitle = rental
        ? [rentalSessionLabel(a), if ((a.guests ?? 0) > 0) '${a.guests} mehmon'].join(' · ')
        : a.staffName;
    final showUnpaid = a.requiresDeposit && a.status.isLive;
    final showPaid = depositPaid(a) && a.status != AppointmentStatus.canceled;
    final canReview = past && (a.canReview ?? false);
    final reviewed = past && a.reviewId != null;
    final canRebook = past && a.status == AppointmentStatus.completed && b != null && b.slug.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push(AppRoutes.appointment(a.id))),
        child: Padding(
          padding: const EdgeInsets.all(BzSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(business: b, chip: AppointmentStatusChip(a.status)),
              const SizedBox(height: BzSpace.m),
              Text(a.serviceName ?? 'Xizmat', style: theme.textTheme.titleMedium),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
              const SizedBox(height: BzSpace.s),
              _MetaRow(
                icon: Icons.event,
                text: UzDates.dateTime(a.startLocal(), today: bookingToday(b)),
              ),
              if (showUnpaid) ...[
                const SizedBox(height: BzSpace.m),
                InfoLine(
                  dense: true,
                  icon: Icons.account_balance_wallet_outlined,
                  text: "Oldindan to'lov: ${Money.format(a.depositTiyin)} · to'lanmagan",
                  foreground: BzColors.warning,
                  background: BzColors.warningBg,
                ),
              ] else if (showPaid) ...[
                const SizedBox(height: BzSpace.m),
                const InfoLine(
                  dense: true,
                  icon: Icons.verified_outlined,
                  text: "Oldindan to'lov qilingan",
                  foreground: BzColors.success,
                  background: BzColors.successBg,
                ),
              ],
              if (canReview || reviewed || canRebook) ...[
                const SizedBox(height: BzSpace.m),
                Row(
                  children: [
                    if (canReview)
                      Expanded(
                        child: SecondaryButton(
                          label: 'Sharh qoldirish',
                          icon: Icons.rate_review_outlined,
                          onPressed: () =>
                              unawaited(context.push(AppRoutes.reviewNew(appointmentId: a.id, businessName: b?.name))),
                        ),
                      )
                    else if (reviewed)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: muted),
                            const SizedBox(width: 6),
                            Text('Sharh qoldirilgan', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                          ],
                        ),
                      ),
                    if ((canReview || reviewed) && canRebook) const SizedBox(width: BzSpace.s),
                    if (canRebook)
                      Expanded(
                        child: SecondaryButton(
                          label: 'Qayta yozilish',
                          icon: Icons.replay,
                          onPressed: () => unawaited(
                            context.push(
                              bookingEntryPath(
                                b.slug,
                                bookingFlowForEngine(b.engine),
                                serviceId: a.serviceId,
                                staffId: a.staffId,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One order in "Bronlarim" > "Buyurtmalar".
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.past});

  final Order order;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = o.business;
    final created = o.createdAt;
    final canReview = past && o.status == OrderStatus.delivered && (o.canReview ?? false);
    final reviewed = past && o.reviewId != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push(AppRoutes.order(o.id))),
        child: Padding(
          padding: const EdgeInsets.all(BzSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(business: b, chip: OrderStatusChip(o.status)),
              const SizedBox(height: BzSpace.m),
              Text(orderItemsLabel(o), style: theme.textTheme.titleMedium),
              const SizedBox(height: BzSpace.s),
              Row(
                children: [
                  Text(
                    Money.format(o.totalTiyin),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                  if (created != null) ...[
                    const SizedBox(width: BzSpace.m),
                    Expanded(
                      child: _MetaRow(
                        icon: Icons.schedule,
                        text: UzDates.dayLabel(Dates.localDateOf(created, bookingTimezone(b)), today: bookingToday(b)),
                      ),
                    ),
                  ],
                ],
              ),
              if (canReview) ...[
                const SizedBox(height: BzSpace.m),
                SecondaryButton(
                  label: 'Sharh qoldirish',
                  icon: Icons.rate_review_outlined,
                  onPressed: () => unawaited(context.push(AppRoutes.reviewNew(orderId: o.id, businessName: b?.name))),
                ),
              ] else if (reviewed) ...[
                const SizedBox(height: BzSpace.m),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Sharh qoldirilgan',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The success hero of a just-created booking or order.
class SuccessHero extends StatelessWidget {
  const SuccessHero({super.key, required this.title, this.subtitle, this.note});

  final String title;
  final String? subtitle;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BzSpace.l),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: BzColors.successBg, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 44, color: BzColors.success),
          ),
          const SizedBox(height: BzSpace.l),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: BzSpace.xs),
            Text(subtitle!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          ],
          if (note != null) ...[
            const SizedBox(height: BzSpace.s),
            Text(
              note!,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// The tappable business block of a detail page: mini header + status chip.
class BusinessBlock extends StatelessWidget {
  const BusinessBlock({super.key, required this.business, required this.chip});

  final BusinessRef? business;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final slug = b?.slug ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: slug.isEmpty ? null : () => unawaited(context.push(AppRoutes.business(slug))),
        child: Padding(
          padding: const EdgeInsets.all(BzSpace.l),
          child: Row(
            children: [
              Expanded(
                child: BusinessMiniHeaderLite(
                  name: b?.name ?? '',
                  logo: b?.logo,
                  brandColor: b?.brandColor,
                  subtitle: slug.isEmpty ? null : "Biznes sahifasini ko'rish",
                ),
              ),
              const SizedBox(width: BzSpace.s),
              chip,
            ],
          ),
        ),
      ),
    );
  }
}

/// [BusinessMiniHeader]-like row with a chevron-friendly subtitle; kept local so the card owns
/// its tap area.
class BusinessMiniHeaderLite extends StatelessWidget {
  const BusinessMiniHeaderLite({super.key, required this.name, this.logo, this.brandColor, this.subtitle});

  final String name;
  final String? logo;
  final String? brandColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        BizLogo(url: logo, name: name, size: 40, brandColor: brandColor),
        const SizedBox(width: BzSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled card section (Izoh, Holat ...).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BzSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: BzSpace.s),
            child,
          ],
        ),
      ),
    );
  }
}
