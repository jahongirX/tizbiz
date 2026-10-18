import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Shared building blocks of the grouped-card look: a soft indigo gradient page, a large page
/// title, white rounded groups of rows with icon tiles and chevrons, and a grey pill button.

bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// The page background: [BzColors.bgTop] at the top fading into [BzColors.bg].
class BzBackground extends StatelessWidget {
  const BzBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35],
          colors: dark ? const [BzColors.darkBgTop, BzColors.darkBg] : const [BzColors.bgTop, BzColors.bg],
        ),
      ),
      child: child,
    );
  }
}

/// A big bold page title (`Bronlarim`, `Sevimlilar`) with optional trailing actions.
class BzLargeTitle extends StatelessWidget {
  const BzLargeTitle({super.key, required this.title, this.actions = const [], this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.xl, BzSpace.xl, BzSpace.s, BzSpace.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: BzSpace.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A white rounded card holding rows (or any children), with [BzSpace.gutter] side margins.
class BzGroup extends StatelessWidget {
  const BzGroup({super.key, required this.children, this.padding, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: BzSpace.s),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// A rounded square holding an icon (grey tile; [color] tints the icon).
class BzIconTile extends StatelessWidget {
  const BzIconTile({super.key, required this.icon, this.color, this.background, this.size = 48});

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? (dark ? BzColors.darkTile : BzColors.tile),
        borderRadius: BorderRadius.circular(BzRadius.tile),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? Theme.of(context).colorScheme.onSurface),
    );
  }
}

/// A row inside a [BzGroup]: leading (icon tile / logo), title, optional subtitle, trailing
/// (a chevron by default when tappable).
class BzRow extends StatelessWidget {
  const BzRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.trailingText,
    this.onTap,
    this.danger = false,
    this.showChevron,
    this.tileIcon = true,
  });

  final String title;
  final String? subtitle;

  /// Shown in a [BzIconTile] (or bare when [tileIcon] is false); ignored when [leading] is set.
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  /// Muted text before the chevron (`Barcha shaharlar`).
  final String? trailingText;
  final VoidCallback? onTap;
  final bool danger;

  /// Defaults to `onTap != null`.
  final bool? showChevron;
  final bool tileIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = danger ? scheme.error : scheme.onSurface;
    final lead =
        leading ??
        (icon == null
            ? null
            : tileIcon
            ? BzIconTile(icon: icon!, color: danger ? scheme.error : null)
            : Icon(icon, size: 26, color: fg));
    final chevron = showChevron ?? onTap != null;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.l, vertical: 10),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: BzSpace.s),
                Flexible(
                  child: Text(
                    trailingText!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: BzSpace.s), trailing!],
              if (chevron && trailing == null) ...[
                const SizedBox(width: BzSpace.xs),
                Icon(BzIcons.chevronRight, size: 20, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width grey pill button (`Hammasini ko'rish`).
class BzPillButton extends StatelessWidget {
  const BzPillButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: _dark(context) ? BzColors.darkTile : BzColors.tile,
      borderRadius: BorderRadius.circular(BzRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: BzSpace.l),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: BzSpace.s)],
              Flexible(
                child: Text(label, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section title above a group (`Tavsiya etilgan` + `Hammasi`).
class BzSectionTitle extends StatelessWidget {
  const BzSectionTitle({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.xl, BzSpace.xxl, BzSpace.s, BzSpace.m),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(actionLabel!), const Icon(BzIcons.chevronRight, size: 16)],
              ),
            ),
        ],
      ),
    );
  }
}

/// A transparent app bar with a large bold title, for the tab pages (`Bronlarim`).
AppBar bzLargeAppBar(BuildContext context, String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    scrolledUnderElevation: 0,
    toolbarHeight: 76,
    titleSpacing: BzSpace.xl,
    title: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineLarge)),
    actions: actions,
    bottom: bottom,
  );
}
