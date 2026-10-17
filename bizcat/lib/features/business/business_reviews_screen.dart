import 'dart:async';

import 'package:bizcat/core/errors.dart';
import 'package:bizcat/features/business/providers.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/rating.dart';
import 'package:bizcat/shared/widgets/review_tile.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// All public reviews of a business, with a star filter and paging.
class BusinessReviewsScreen extends ConsumerStatefulWidget {
  const BusinessReviewsScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends ConsumerState<BusinessReviewsScreen> {
  int? _rating;

  ReviewsKey get _key => (slug: widget.slug, rating: _rating);

  Future<void> _refresh() async {
    ref.invalidate(businessReviewsProvider(_key));
    try {
      await ref.read(businessReviewsProvider(_key).future);
    } on Object {
      // Shown by the list.
    }
  }

  bool _onScroll(ScrollNotification n) {
    final current = ref.read(businessReviewsProvider(_key)).value;
    if (current == null || current.moreError != null) return false;
    if (n.metrics.extentAfter < 400) unawaited(ref.read(businessReviewsProvider(_key).notifier).loadMore());
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(businessReviewsProvider(_key));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => popOrGo(context)),
        title: const Text('Sharhlar'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.s),
              children: [
                for (final r in const <int?>[null, 5, 4, 3, 2, 1]) ...[
                  ChoiceChip(
                    key: ValueKey('rating-${r ?? 'all'}'),
                    label: Text(r == null ? 'Barchasi' : '$r★'),
                    selected: _rating == r,
                    onSelected: (_) => setState(() => _rating = r),
                  ),
                  const SizedBox(width: BzSpace.s),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<ReviewsPage>(
              value: value,
              onRetry: () => ref.invalidate(businessReviewsProvider(_key)),
              builder: (data) => NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, BzSpace.xxl),
                    children: [
                      if (data.summary.count > 0) ...[
                        RatingSummaryView(summary: data.summary),
                        const SizedBox(height: BzSpace.l),
                      ],
                      if (data.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: BzSpace.xxl),
                          child: EmptyState(
                            icon: Icons.rate_review_outlined,
                            title: _rating == null ? "Hali sharhlar yo'q" : "Bu baho bilan sharhlar yo'q.",
                          ),
                        ),
                      for (final r in data.items) ...[ReviewTile(review: r), const SizedBox(height: BzSpace.m)],
                      if (data.loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(BzSpace.l),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (data.moreError != null)
                        Column(
                          children: [
                            Text(errorText(data.moreError!), textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () => unawaited(ref.read(businessReviewsProvider(_key).notifier).loadMore()),
                              child: const Text('Qayta urinish'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
