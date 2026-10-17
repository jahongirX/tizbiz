import 'dart:async';

import 'package:bizcat/shared/widgets/brand.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The common frame of the auth screens: an AppBar with a back button, a scrollable body with
/// the gutter, and an optional pinned footer.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.onBack, this.footer});

  final List<Widget> children;

  /// Default: pop, or go home when nothing can pop.
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Orqaga',
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack ?? () => popOrGo(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, BzSpace.xxl),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(BzSpace.gutter, 0, BzSpace.gutter, BzSpace.l),
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: footer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mark + title (headlineSmall) + muted subtitle.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.subtitle, this.showMark = true});

  final String title;
  final Widget? subtitle;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMark) ...[
          const BrandMark(size: 48),
          const SizedBox(height: BzSpace.xl),
        ],
        Text(title, style: theme.textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: BzSpace.s),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}

enum AuthBannerKind { info, error }

/// A rounded inline message: indigo50 for info, the error container for failures.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.text, this.kind = AuthBannerKind.info, this.action});

  final String text;
  final AuthBannerKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = kind == AuthBannerKind.error;
    final bg = isError ? scheme.errorContainer : scheme.primaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.m, vertical: BzSpace.m),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BzRadius.m)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline, size: 20, color: fg),
            const SizedBox(width: BzSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
                  ?action,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'm:ss' ('0:42', '1:00').
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Rebuilds once a second until [until]; [builder] gets the seconds left (0 = done).
///
/// The remaining time is read from the clock when [until] changes and then counted down by
/// ticks, so widget tests drive it with `tester.pump(Duration)`.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until, required this.builder});

  final DateTime? until;
  final Widget Function(BuildContext context, int secondsLeft) builder;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    final until = widget.until;
    if (until == null) {
      _left = 0;
      return;
    }
    final ms = until.difference(DateTime.now()).inMilliseconds;
    _left = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (_left > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          _timer = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}
