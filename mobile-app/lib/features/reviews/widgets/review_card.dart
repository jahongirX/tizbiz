import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/widgets/star_rating.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One review with the business reply and the reply button.
class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key, required this.review, required this.onReply});

  final Review review;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final tz = ref.watch(activeBusinessProvider)?.timezone;
    final now = ref.read(clockProvider)();
    String ago(DateTime? t) => t == null ? '' : UzDates.ago(t, now: now, timezone: tz);
    final about = [review.serviceName, review.staffName].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final comment = review.comment?.trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StarRating(value: review.rating.toDouble()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    review.authorName.isEmpty ? 'Mijoz' : review.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (review.status == ReviewStatus.hidden)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
                    child: Text('Yashirilgan', style: TextStyle(fontSize: 11, color: c.textMuted)),
                  ),
                Text(ago(review.createdAt), style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(about, style: TextStyle(fontSize: 12, color: c.textMuted)),
            ],
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment),
            ],
            if (review.hasReply) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Sizning javobingiz',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted)),
                        ),
                        Text(ago(review.repliedAt), style: TextStyle(fontSize: 12, color: c.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(review.reply!),
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReply,
                icon: Icon(review.hasReply ? Icons.edit_outlined : Icons.reply_outlined, size: 18),
                label: Text(review.hasReply ? 'Javobni tahrirlash' : 'Javob berish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
