import 'package:material_ui/material_ui.dart';

/// Centres [child] with at most [max] width (forms on web/tablet).
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, this.max = 720, required this.child});

  final double max;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
      );
}
