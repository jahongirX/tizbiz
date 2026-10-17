import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A section title (`titleLarge`) with an optional trailing action (`Hammasi >`).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BzSpace.s, bottom: BzSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(actionLabel!), const Icon(Icons.chevron_right, size: 20)],
              ),
            ),
        ],
      ),
    );
  }
}
