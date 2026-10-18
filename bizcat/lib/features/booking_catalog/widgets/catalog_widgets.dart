import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../copy.dart';
import '../providers.dart';

/// Price text of an item: `Money.format`, or `Narxi kelishiladi` when the price is 0.
String itemPriceLabel(int priceTiyin) => priceTiyin > 0 ? Money.format(priceTiyin) : 'Narxi kelishiladi';

/// A square item photo (radius m) with an indigo50 placeholder icon.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, required this.item, this.size = 72});

  final Service item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = itemImages(item);
    return NetImage(
      url: images.isEmpty ? null : images.first,
      width: size,
      height: size,
      radius: BorderRadius.circular(BzRadius.m),
      placeholder: Container(
        width: size,
        height: size,
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: Icon(BzIcons.image, size: size * 0.38, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// `−  n  +` in an outlined pill. [onInc] is disabled at [kMaxLineQty].
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onDec,
    required this.onInc,
    this.compact = true,
    this.min = 0,
  });

  final int qty;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  /// 36 px buttons (rows) instead of 44 px (the item sheet).
  final bool compact;

  /// [onDec] is disabled at this quantity.
  final int min;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final side = compact ? 36.0 : 44.0;
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => SizedBox(
      width: side,
      height: side,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: compact ? 18 : 22,
        tooltip: tooltip,
        color: scheme.primary,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.primary, width: 1.2),
        borderRadius: BorderRadius.circular(BzRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(BzIcons.remove, CatalogText.decrease, qty > min ? onDec : null),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 24 : 32),
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
            ),
          ),
          button(BzIcons.add, CatalogText.increase, qty < kMaxLineQty ? onInc : null),
        ],
      ),
    );
  }
}

/// A small outlined `Qo'shish` button for item rows (per-item actions never use the CTA colour).
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.m),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        icon: const Icon(BzIcons.add, size: 18),
        label: const Text(CatalogText.add),
      ),
    );
  }
}

/// An info card (indigo50) with an icon, a text and an optional action.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(BzSpace.m),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(BzRadius.m)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: BzSpace.s),
              Expanded(
                child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: BzSpace.s),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}

/// The error box under the checkout form.
class CatalogAlert extends StatelessWidget {
  const CatalogAlert({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BzSpace.l),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(BzRadius.m)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(BzIcons.danger, color: scheme.onErrorContainer, size: 20),
                const SizedBox(width: BzSpace.s),
                Expanded(
                  child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: BzSpace.m), action!],
          ],
        ),
      ),
    );
  }
}
