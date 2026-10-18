import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The main call to action of a screen: apricot background, indigo label and icon.
///
/// **The only apricot button.** At most one per visible screen.
class CtaButton extends StatelessWidget {
  const CtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a 20 px indigo spinner and ignores taps.
  final bool loading;
  final IconData? icon;

  /// Full width when true.
  final bool expanded;

  static final ButtonStyle style = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) return BzColors.border;
      if (s.contains(WidgetState.pressed)) return BzColors.apricot600;
      return BzColors.apricot;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? BzColors.muted : BzColors.indigo,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? BzColors.muted : BzColors.indigo,
    ),
    overlayColor: const WidgetStatePropertyAll(Color(0x14000000)),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(BzRadius.m))),
  );

  @override
  Widget build(BuildContext context) {
    return _ButtonFrame(
      expanded: expanded,
      loading: loading,
      child: FilledButton(
        style: style,
        onPressed: onPressed == null ? null : (loading ? () {} : onPressed),
        child: _ButtonContent(label: label, icon: icon, loading: loading, spinnerColor: BzColors.indigo),
      ),
    );
  }
}

/// Indigo filled button (the theme's FilledButton).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ButtonFrame(
      expanded: expanded,
      loading: loading,
      child: FilledButton(
        onPressed: onPressed == null ? null : (loading ? () {} : onPressed),
        child: _ButtonContent(label: label, icon: icon, loading: loading, spinnerColor: scheme.onPrimary),
      ),
    );
  }
}

/// Indigo outlined button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ButtonFrame(
      expanded: expanded,
      loading: loading,
      child: OutlinedButton(
        onPressed: onPressed == null ? null : (loading ? () {} : onPressed),
        child: _ButtonContent(label: label, icon: icon, loading: loading, spinnerColor: scheme.primary),
      ),
    );
  }
}

/// A danger-colored text button (delete account, cancel booking).
class DangerTextButton extends StatelessWidget {
  const DangerTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: danger),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _ButtonFrame extends StatelessWidget {
  const _ButtonFrame({required this.expanded, required this.loading, required this.child});

  final bool expanded;
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = IgnorePointer(ignoring: loading, child: child);
    return expanded ? SizedBox(width: double.infinity, child: c) : c;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, required this.icon, required this.loading, required this.spinnerColor});

  final String label;
  final IconData? icon;
  final bool loading;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor));
    }
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: BzSpace.s),
        Flexible(child: text),
      ],
    );
  }
}
