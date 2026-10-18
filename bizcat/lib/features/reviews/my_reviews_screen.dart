import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/features/reviews/providers.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/review_tile.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/shared/widgets/status_chips.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// "Sharhlarim": my reviews with edit / delete.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Review r) async {
    final ok = await confirmDialog(
      context,
      title: "Sharhni o'chirish",
      message: "Sharhingiz butunlay o'chiriladi.",
      confirmLabel: "O'chirish",
      danger: true,
    );
    if (!ok) return;
    if (await ref.read(reviewActionsProvider).delete(r.id)) showSnack("O'chirildi.");
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myReviewsProvider);
    Future<void> refresh() async {
      ref.invalidate(myReviewsProvider);
      try {
        await ref.read(myReviewsProvider.future);
      } on Object {
        // Shown by the list.
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => popOrGo(context, AppRoutes.profile)),
        title: const Text('Sharhlarim'),
      ),
      body: AsyncBody<List<Review>>(
        value: value,
        onRetry: () => ref.invalidate(myReviewsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: BzSpace.xxl),
            children: const [
              EmptyState(
                icon: BzIcons.review,
                title: 'Hali sharh qoldirmagansiz',
                message: 'Yakunlangan tashriflaringizni "Bronlarim" bo\'limida baholang.',
              ),
            ],
          ),
        ),
        builder: (list) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxl),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: BzSpace.m),
            itemBuilder: (context, i) {
              final r = list[i];
              final tile = ReviewTile(
                review: r,
                showBusiness: true,
                onEdit: () => unawaited(context.push(AppRoutes.reviewEdit(r.id))),
                onDelete: () => unawaited(_delete(context, ref, r)),
              );
              if (r.status != ReviewStatus.hidden) return tile;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: BzSpace.xs),
                    child: StatusPill(
                      label: 'Yashirilgan',
                      foreground: BzColors.neutral,
                      background: BzColors.neutralBg,
                    ),
                  ),
                  tile,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
