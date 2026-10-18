import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Skeleton shapes for [LoadingView].
enum LoadingKind { list, cards, detail, grid }

/// Skeleton blocks with a pulsing opacity (no package).
///
/// The pulse repeats, so `tester.pumpAndSettle()` never settles while it is visible: in tests
/// use `tester.pump(...)`, or wait until the data arrived.
class LoadingView extends StatefulWidget {
  const LoadingView({super.key, this.rows = 6, this.kind = LoadingKind.list});

  final int rows;
  final LoadingKind kind;

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    Widget box({double? w, required double h, double r = BzRadius.s}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r)),
    );

    final Widget body;
    switch (widget.kind) {
      case LoadingKind.list:
        body = Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: BzSpace.l),
                child: Row(
                  children: [
                    box(w: 48, h: 48, r: BzRadius.m),
                    const SizedBox(width: BzSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          box(h: 14),
                          const SizedBox(height: BzSpace.s),
                          box(w: 120, h: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case LoadingKind.cards:
        body = Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: BzSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 2,
                      child: box(h: double.infinity, r: BzRadius.l),
                    ),
                    const SizedBox(height: BzSpace.s),
                    box(w: 180, h: 14),
                    const SizedBox(height: BzSpace.xs),
                    box(w: 120, h: 12),
                  ],
                ),
              ),
          ],
        );
      case LoadingKind.detail:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: box(h: double.infinity, r: BzRadius.l),
            ),
            const SizedBox(height: BzSpace.l),
            box(w: 200, h: 22),
            const SizedBox(height: BzSpace.s),
            box(w: 140, h: 14),
            const SizedBox(height: BzSpace.xxl),
            for (var i = 0; i < widget.rows; i++) ...[box(h: 14), const SizedBox(height: BzSpace.m)],
          ],
        );
      case LoadingKind.grid:
        body = GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: BzSpace.m,
          crossAxisSpacing: BzSpace.m,
          children: [for (var i = 0; i < widget.rows; i++) box(h: double.infinity, r: BzRadius.l)],
        );
    }

    return Semantics(
      label: 'Yuklanmoqda...',
      child: FadeTransition(
        opacity: _c,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.l),
          child: body,
        ),
      ),
    );
  }
}

/// Centered icon (in an indigo50 circle), title, optional message and indigo action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.xxxl, vertical: BzSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: BzSpace.l),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: BzSpace.s),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: BzSpace.xl),
              PrimaryButton(label: actionLabel!, onPressed: onAction, expanded: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic error with `Qayta urinish`.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: BzIcons.danger,
    title: message,
    actionLabel: onRetry == null ? null : 'Qayta urinish',
    onAction: onRetry,
  );
}

/// No connection: `Internet aloqasi yo'q` with `Qayta urinish`.
class OfflineState extends StatelessWidget {
  const OfflineState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: BzIcons.offline,
    title: "Internet aloqasi yo'q",
    message: "Ulanishni tekshirib, qayta urinib ko'ring.",
    actionLabel: onRetry == null ? null : 'Qayta urinish',
    onAction: onRetry,
  );
}
