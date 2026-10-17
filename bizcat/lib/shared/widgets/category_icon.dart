import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Server icon key -> Material icon.
IconData categoryIconData(String? icon) => switch (icon) {
      'scissors' => Icons.content_cut,
      'cake' => Icons.cake_outlined,
      'utensils' => Icons.restaurant,
      'stethoscope' => Icons.medical_services_outlined,
      'rings' => Icons.celebration_outlined,
      _ => Icons.storefront_outlined,
    };

/// 'Barber / Go'zallik saloni' -> 'Barber'.
String categoryShortLabel(String label) {
  final i = label.indexOf(' / ');
  return (i < 0 ? label : label.substring(0, i)).trim();
}

/// White card: icon in an indigo50 circle, short label, `<count> ta`.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.onTap});

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.s, vertical: BzSpace.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(categoryIconData(category.icon), color: scheme.primary, size: 22),
              ),
              const SizedBox(height: BzSpace.s),
              Text(
                categoryShortLabel(category.label),
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text('${category.count} ta', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
