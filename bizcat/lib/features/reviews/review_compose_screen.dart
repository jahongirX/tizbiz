import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/features/reviews/providers.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Caption under the stars for ratings 1..5.
String ratingCaption(int rating) => switch (rating) {
  1 => 'Yomon',
  2 => 'Qoniqarsiz',
  3 => "O'rtacha",
  4 => 'Yaxshi',
  5 => "A'lo",
  _ => '',
};

/// Create a review for a visit (appointment or order), or edit / delete one of mine.
class ReviewComposeScreen extends ConsumerStatefulWidget {
  const ReviewComposeScreen({super.key, this.appointmentId, this.orderId, this.reviewId, this.businessName});

  final int? appointmentId;
  final int? orderId;
  final int? reviewId;
  final String? businessName;

  @override
  ConsumerState<ReviewComposeScreen> createState() => _ReviewComposeScreenState();
}

class _ReviewComposeScreenState extends ConsumerState<ReviewComposeScreen> {
  final _comment = TextEditingController();

  ReviewTarget get _target => (appointmentId: widget.appointmentId, orderId: widget.orderId, reviewId: widget.reviewId);

  bool get _isEdit => widget.reviewId != null;

  @override
  void initState() {
    super.initState();
    final s = ref.read(reviewComposeProvider(_target));
    if (!s.loading) _comment.text = s.comment;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _leave() => popOrGo(context, AppRoutes.bookings);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await ref.read(reviewComposeProvider(_target).notifier).submit();
    if (!ok || !mounted) return;
    showSnack(_isEdit ? 'Saqlandi.' : 'Rahmat! Sharhingiz qabul qilindi.');
    _leave();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: "Sharhni o'chirish",
      message: "Sharhingiz butunlay o'chiriladi.",
      confirmLabel: "O'chirish",
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(reviewComposeProvider(_target).notifier).delete();
    if (!ok || !mounted) return;
    showSnack("O'chirildi.");
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewComposeProvider(_target);
    ref.listen(provider, (prev, next) {
      if ((prev?.loading ?? true) && !next.loading && _comment.text.isEmpty) _comment.text = next.comment;
    });
    final s = ref.watch(provider);
    final title = _isEdit ? 'Sharhni tahrirlash' : 'Sharh qoldirish';
    final missingTarget = !_isEdit && widget.appointmentId == null && widget.orderId == null;

    Widget scaffold(Widget body, {Widget? bottom}) => Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _leave),
        title: Text(title),
      ),
      body: body,
      bottomNavigationBar: bottom,
    );

    if (missingTarget) {
      return scaffold(
        EmptyState(
          icon: BzIcons.review,
          title: 'Tashrif tanlanmagan',
          message: "Sharhni \"Bronlarim\" bo'limidagi yakunlangan tashrifdan qoldiring.",
          actionLabel: 'Bronlarim',
          onAction: () => context.go(AppRoutes.bookings),
        ),
      );
    }
    if (s.loading) return scaffold(const LoadingView(rows: 3));
    final error = s.error;
    if (error != null) {
      if (error is ApiException && error.isNotFound) {
        return scaffold(
          EmptyState(icon: BzIcons.review, title: 'Sharh topilmadi', actionLabel: 'Orqaga', onAction: _leave),
        );
      }
      if (error is ApiException && error.isConflict) {
        return scaffold(
          EmptyState(icon: BzIcons.info, title: errorText(error), actionLabel: 'Orqaga', onAction: _leave),
        );
      }
      return scaffold(
        isOffline(error)
            ? OfflineState(onRetry: () => ref.invalidate(myReviewsProvider))
            : ErrorState(message: errorText(error), onRetry: () => ref.invalidate(myReviewsProvider)),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ctrl = ref.read(provider.notifier);
    final name = (widget.businessName ?? s.existing?.business?.name ?? '').trim();
    final caption = ratingCaption(s.rating);

    return scaffold(
      ListView(
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xl, BzSpace.gutter, BzSpace.xxl),
        children: [
          Text(
            name.isEmpty ? 'Tashrifingiz qanday bo\'ldi?' : '$name qanday bo\'ldi?',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BzSpace.l),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var n = 1; n <= 5; n++)
                Semantics(
                  label: '$n yulduz',
                  button: true,
                  selected: n <= s.rating,
                  excludeSemantics: true,
                  child: IconButton(
                    key: ValueKey('star-$n'),
                    iconSize: 44,
                    onPressed: s.submitting ? null : () => ctrl.setRating(n),
                    icon: Icon(n <= s.rating ? Icons.star_rounded : Icons.star_outline_rounded, color: scheme.primary),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 24,
            child: Center(
              child: s.ratingError != null
                  ? Text(s.ratingError!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))
                  : Text(caption, style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
            ),
          ),
          const SizedBox(height: BzSpace.xl),
          TextField(
            controller: _comment,
            enabled: !s.submitting,
            minLines: 5,
            maxLines: 8,
            maxLength: kReviewCommentMax,
            textCapitalization: TextCapitalization.sentences,
            onChanged: ctrl.setComment,
            decoration: InputDecoration(
              labelText: 'Fikringiz (ixtiyoriy)',
              hintText: 'Xizmat, usta, muhit haqida yozing',
              alignLabelWithHint: true,
              errorText: s.commentError,
            ),
          ),
          if (s.isEdit) ...[
            const SizedBox(height: BzSpace.l),
            Center(
              child: DangerTextButton(
                label: "Sharhni o'chirish",
                onPressed: s.submitting ? null : () => unawaited(_delete()),
              ),
            ),
          ],
        ],
      ),
      bottom: BottomActionBar(
        child: CtaButton(
          label: _isEdit ? 'Saqlash' : 'Yuborish',
          loading: s.submitting,
          onPressed: s.submitting ? null : () => unawaited(_submit()),
        ),
      ),
    );
  }
}
