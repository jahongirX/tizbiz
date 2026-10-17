import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/reviews/actions.dart';
import 'package:tizbiz_biznes/features/reviews/providers.dart';
import 'package:tizbiz_biznes/features/reviews/widgets/rating_summary_card.dart';
import 'package:tizbiz_biznes/features/reviews/widgets/reply_sheet.dart';
import 'package:tizbiz_biznes/features/reviews/widgets/review_card.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/paged_list_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kReviewsEmpty = "Hali sharhlar yo'q. Mijozlar Bizcat ilovasi orqali sharh qoldiradi.";

/// Sharhlar (BIZNES-SPEC §9.10).
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  Future<void> _reply(BuildContext context, WidgetRef ref, ReviewsFilterValue filter, Review review) async {
    final saved = await ReplySheet.show(
      context,
      review: review,
      onSubmit: (text) => ref.read(reviewActionsProvider).reply(review.id, text),
    );
    if (saved == null) return;
    ref.read(reviewsPagedProvider(filter).notifier).replaceItem(saved);
    if (context.mounted) showAppSnack(context, 'Javob saqlandi');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reviewsFilterProvider);
    final value = ref.watch(reviewsPagedProvider(filter));
    final filtered = filter.rating != null || filter.hasReply != null;

    Future<void> loadMore() async {
      try {
        await ref.read(reviewsPagedProvider(filter).notifier).loadMore();
      } catch (e) {
        if (context.mounted) showAppSnack(context, errorText(e), error: true);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sharhlar')),
      body: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const _FilterChips(),
            const SizedBox(height: 4),
            Expanded(
              child: AsyncBody<ReviewsPage>(
                value: value,
                onRetry: () => ref.invalidate(reviewsPagedProvider(filter)),
                loading: const SkeletonList(),
                data: (d) => PagedListView<Review>(
                  page: d.page,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RatingSummaryCard(summary: d.summary),
                      if (d.page.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: EmptyView(
                            icon: Icons.rate_review_outlined,
                            title: filtered ? "Bu filtr bo'yicha sharhlar yo'q" : kReviewsEmpty,
                          ),
                        ),
                    ],
                  ),
                  separator: const SizedBox(height: 4),
                  onLoadMore: loadMore,
                  onRefresh: () => ref.refresh(reviewsPagedProvider(filter).future),
                  itemBuilder: (context, r) => ReviewCard(review: r, onReply: () => _reply(context, ref, filter, r)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(reviewsFilterProvider);
    final n = ref.read(reviewsFilterProvider.notifier);
    Widget choice(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          choice('Hammasi', f.hasReply == null, () => n.setHasReply(null)),
          choice('Javobsiz', f.hasReply == false, () => n.setHasReply(false)),
          choice('Javob berilgan', f.hasReply == true, () => n.setHasReply(true)),
          const SizedBox(width: 8),
          for (var s = 5; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Icon(Icons.star_rounded, size: 16, color: AppColors.star),
                label: Text('$s'),
                selected: f.rating == s,
                onSelected: (_) => n.setRating(f.rating == s ? null : s),
              ),
            ),
        ],
      ),
    );
  }
}
