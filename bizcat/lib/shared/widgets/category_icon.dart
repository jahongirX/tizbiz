import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Server icon key -> Material icon.
IconData categoryIconData(String? icon) => switch (icon) {
  'scissors' => BzIcons.scissor,
  'cake' => BzIcons.cake,
  'utensils' => BzIcons.restaurant,
  'stethoscope' => BzIcons.hospital,
  'rings' => BzIcons.wedding,
  _ => BzIcons.shop,
};

/// 'Barber / Go'zallik saloni' -> 'Barber'.
String categoryShortLabel(String label) {
  final i = label.indexOf(' / ');
  return (i < 0 ? label : label.substring(0, i)).trim();
}

/// A colorful category card (brand gradients in turn): big icon top-right, short label and
/// `<count> ta` bottom-left.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.onTap, this.index = 0});

  final Category category;
  final VoidCallback? onTap;

  /// Position in the row: picks the gradient.
  final int index;

  static const double width = 124, height = 128;

  /// (gradient, foreground): indigo text on apricot (brand rule), white on indigo.
  static const List<(List<Color>, Color)> palettes = [
    ([BzColors.indigo700, BzColors.indigo], BzColors.white),
    ([Color(0xFFFFA27C), BzColors.apricot600], BzColors.indigo),
    ([Color(0xFF5048B5), Color(0xFF2B2672)], BzColors.white),
    ([Color(0xFFFFD3BF), Color(0xFFFFAE8C)], BzColors.indigo),
    ([Color(0xFF6E6A9E), Color(0xFF3B3766)], BzColors.white),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (colors, fg) = palettes[index % palettes.length];
    return Semantics(
      button: true,
      label: '${categoryShortLabel(category.label)}, ${category.count} ta',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BzRadius.xl),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(BzRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -10,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), shape: BoxShape.circle),
                  ),
                ),
                Positioned(right: 12, top: 12, child: Icon(categoryIconData(category.icon), color: fg, size: 30)),
                Positioned(
                  left: 12,
                  right: 8,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryShortLabel(category.label),
                        style: theme.textTheme.titleSmall?.copyWith(color: fg, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${category.count} ta',
                        style: theme.textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
