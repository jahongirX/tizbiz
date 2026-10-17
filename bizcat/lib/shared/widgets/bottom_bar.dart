import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A white bar with a top border for sticky CTAs (`Scaffold.bottomNavigationBar`).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.leading});

  final Widget child;

  /// Optional widget left of [child] (e.g. a total).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BzSpace.l),
          child: leading == null
              ? child
              : Row(
                  children: [
                    leading!,
                    const SizedBox(width: BzSpace.m),
                    Expanded(child: child),
                  ],
                ),
        ),
      ),
    );
  }
}
