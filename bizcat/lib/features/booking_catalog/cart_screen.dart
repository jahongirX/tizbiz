import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/booking_catalog/copy.dart';
import 'package:bizcat/features/booking_catalog/providers.dart';
import 'package:bizcat/features/booking_catalog/widgets/catalog_widgets.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/dialogs.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// `/b/:slug/cart`: the cart lines, the total and the way to checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key, required this.slug});

  final String slug;

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context, title: '${CatalogText.clearCart}?', confirmLabel: 'Tozalash', danger: true);
    if (ok) ref.read(cartProvider(slug).notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider(slug));
    final ctl = ref.read(cartProvider(slug).notifier);
    final engine = ref.watch(storefrontProvider(slug)).value?.engine;
    final copy = CatalogCopy.forEngine(engine);
    final theme = Theme.of(context);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.cartTitle)),
        body: EmptyState(
          icon: BzIcons.bag,
          title: copy.emptyCart,
          actionLabel: CatalogText.backToMenu,
          onAction: () => popOrGo(context, AppRoutes.menu(slug)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.cartTitle),
        actions: [
          IconButton(
            tooltip: CatalogText.clearCart,
            icon: const Icon(BzIcons.delete),
            onPressed: () => unawaited(_clear(context, ref)),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: CatalogText.checkout,
          onPressed: () => unawaited(context.push(AppRoutes.checkout(slug))),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxxl),
        children: [
          for (final line in cart.lines.values)
            Dismissible(
              key: ValueKey('cart-line-${line.item.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: BzSpace.l),
                color: theme.colorScheme.errorContainer,
                child: Icon(BzIcons.delete, color: theme.colorScheme.onErrorContainer),
              ),
              onDismissed: (_) => ctl.remove(line.item.id),
              child: _CartLineRow(
                line: line,
                onDec: () => ctl.dec(line.item.id),
                onInc: () => ctl.setQty(line.item.id, line.qty + 1),
                onRemove: () => ctl.remove(line.item.id),
              ),
            ),
          const SizedBox(height: BzSpace.l),
          SummaryCard(
            rows: [SummaryRow(label: CatalogText.total, value: Money.format(cart.totalTiyin), emphasize: true)],
          ),
          const SizedBox(height: BzSpace.m),
          Text(copy.pickupNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line, required this.onDec, required this.onInc, required this.onRemove});

  final CartLine line;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BzSpace.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemThumb(item: line.item, size: 56),
          const SizedBox(width: BzSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.item.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: BzSpace.xs),
                Text(
                  itemPriceLabel(line.item.priceTiyin),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: BzSpace.s),
                QtyStepper(qty: line.qty, min: 1, onDec: onDec, onInc: onInc),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: CatalogText.remove,
                visualDensity: VisualDensity.compact,
                icon: const Icon(BzIcons.close),
                onPressed: onRemove,
              ),
              Text(
                Money.format(line.totalTiyin),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
