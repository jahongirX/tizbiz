import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One review: author, stars, age, service/staff, comment and the business reply.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.showBusiness = false, this.onEdit, this.onDelete});

  final Review review;

  /// Adds the business name as the title (tap -> business page).
  final bool showBusiness;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final meta = [review.serviceName, review.staffName].whereType<String>().where((s) => s.trim().isNotEmpty);
    final business = review.business;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BzSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBusiness && business != null)
            InkWell(
              onTap: business.slug.isEmpty ? null : () => unawaited(context.push(AppRoutes.business(business.slug))),
              child: Padding(
                padding: const EdgeInsets.only(bottom: BzSpace.xs),
                child: Text(business.name, style: theme.textTheme.titleMedium),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  review.authorName.isEmpty ? 'Mijoz' : review.authorName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (review.createdAt != null)
                Text(UzDates.ago(review.createdAt!, now: now), style: theme.textTheme.bodySmall),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(BzIcons.more, color: scheme.onSurfaceVariant),
                  onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                    if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text("O'chirish")),
                  ],
                ),
            ],
          ),
          const SizedBox(height: BzSpace.xs),
          RatingStars(value: review.rating.toDouble(), size: 14),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: BzSpace.xs),
            Text(meta.join(' · '), style: theme.textTheme.bodySmall),
          ],
          if ((review.comment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: BzSpace.s),
            Text(review.comment!, style: theme.textTheme.bodyMedium),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: BzSpace.s),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BzSpace.m),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(BzRadius.m),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Biznes javobi', style: theme.textTheme.labelMedium)),
                      if (review.repliedAt != null)
                        Text(UzDates.ago(review.repliedAt!, now: now), style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: BzSpace.xs),
                  Text(review.reply!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
