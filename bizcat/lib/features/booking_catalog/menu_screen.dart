import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/booking_catalog/copy.dart';
import 'package:bizcat/features/booking_catalog/providers.dart';
import 'package:bizcat/features/booking_catalog/widgets/catalog_widgets.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// `/b/:slug/menu`: categories with items, a cart bar and the item sheet (port of web
/// CatalogEngineApp.vue). `reorderOrderId` prefills the cart from a past order once.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key, required this.slug, this.reorderOrderId});

  final String slug;
  final int? reorderOrderId;

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool _redirected = false;
  bool _reorderHandled = false;

  void _handleReorder(StorefrontData data) {
    final id = widget.reorderOrderId;
    if (id == null || _reorderHandled) return;
    final src = ref.watch(reorderSourceProvider(id));
    if (src.hasError && !src.isLoading) {
      _reorderHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => showSnack(CatalogText.reorderFailed));
      return;
    }
    if (!src.hasValue) return;
    _reorderHandled = true;
    final order = src.value;
    if (order == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cart = ref.read(cartProvider(widget.slug).notifier);
      if (!cart.markReorder(id)) return;
      final skipped = await cart.applyReorder(order, data);
      showSnack(skipped > 0 ? CatalogText.itemsGone : CatalogText.reorderApplied);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storefrontProvider(widget.slug));
    final data = store.value;

    if (data != null && !(store.hasError && !store.isLoading)) {
      final flow = bookingFlowFor(data);
      if (flow != BookingFlow.catalog) {
        if (!_redirected) {
          _redirected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.replace(bookingEntryPath(widget.slug, flow));
          });
        }
        return const _PlainScaffold(title: 'Menyu', body: LoadingView());
      }
      _handleReorder(data);
      return _MenuView(slug: widget.slug, store: data);
    }

    return _PlainScaffold(
      title: 'Menyu',
      body: AsyncBody<StorefrontData>(
        value: store,
        onRetry: () => ref.invalidate(storefrontProvider(widget.slug)),
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PlainScaffold extends StatelessWidget {
  const _PlainScaffold({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: body);
}

class _MenuView extends ConsumerStatefulWidget {
  const _MenuView({required this.slug, required this.store});

  final String slug;
  final StorefrontData store;

  @override
  ConsumerState<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends ConsumerState<_MenuView> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<int, GlobalKey> _headerKeys = {};
  final Map<int, GlobalKey> _chipKeys = {};
  List<CatalogSection> _sections = const [];
  int? _active;
  bool _jumping = false;

  GlobalKey _headerKey(int id) => _headerKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey _chipKey(int id) => _chipKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncActive);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The selected chip follows the last section header that reached the top of the list.
  void _syncActive() {
    if (_jumping || _sections.isEmpty) return;
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    int current = _sections.first.id;
    for (final s in _sections) {
      final box = _headerKeys[s.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy - top <= BzSpace.xl) {
        current = s.id;
      } else {
        break;
      }
    }
    if (current != _active) _activate(current);
  }

  void _activate(int id) {
    setState(() => _active = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipKeys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        unawaited(Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 200)));
      }
    });
  }

  Future<void> _jumpTo(int id) async {
    final ctx = _headerKeys[id]?.currentContext;
    _activate(id);
    if (ctx == null) return;
    _jumping = true;
    try {
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } finally {
      _jumping = false;
    }
  }

  void _openItem(Service item) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _ItemSheet(slug: widget.slug, item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final copy = CatalogCopy.forEngine(store.engine);
    final cart = ref.watch(cartProvider(widget.slug));
    final cartCtl = ref.read(cartProvider(widget.slug).notifier);
    _sections = catalogSections(store);
    final active = _active ?? (_sections.isEmpty ? null : _sections.first.id);

    final Widget body;
    if (_sections.isEmpty) {
      body = EmptyState(icon: Icons.restaurant_menu, title: copy.emptyMenu);
    } else {
      body = Column(
        children: [
          _CategoryBar(
            sections: _sections,
            active: active,
            chipKey: _chipKey,
            onTap: (id) => unawaited(_jumpTo(id)),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(storefrontProvider(widget.slug));
                await ref.read(storefrontProvider(widget.slug).future);
              },
              child: SingleChildScrollView(
                key: _viewportKey,
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: BzSpace.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in _sections) ...[
                      Padding(
                        key: _headerKey(s.id),
                        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xl, BzSpace.gutter, BzSpace.s),
                        child: Text(s.name, style: Theme.of(context).textTheme.titleLarge),
                      ),
                      for (final item in s.items)
                        _ItemRow(
                          item: item,
                          qty: cart.qtyOf(item.id),
                          onTap: () => _openItem(item),
                          onAdd: () => cartCtl.add(item),
                          onDec: () => cartCtl.dec(item.id),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(store.business.name)),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _CartBar(
              cart: cart,
              onOpen: () => unawaited(context.push(AppRoutes.cart(widget.slug))),
            ),
      body: body,
    );
  }
}

// ---------------------------------------------------------------- category bar

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.sections, required this.active, required this.chipKey, required this.onTap});

  final List<CatalogSection> sections;
  final int? active;
  final GlobalKey Function(int id) chipKey;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.s),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: BzSpace.s),
        itemBuilder: (context, i) {
          final s = sections[i];
          final selected = s.id == active;
          return ChoiceChip(
            key: chipKey(s.id),
            label: Text(s.name),
            selected: selected,
            showCheckmark: false,
            selectedColor: scheme.primary,
            labelStyle: theme.textTheme.labelLarge?.copyWith(color: selected ? scheme.onPrimary : scheme.onSurface),
            onSelected: (_) => onTap(s.id),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- item row

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.qty, required this.onTap, required this.onAdd, required this.onDec});

  final Service item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final description = item.description?.trim();
    return InkWell(
      key: ValueKey('menu-item-${item.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemThumb(item: item),
            const SizedBox(width: BzSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleMedium),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: BzSpace.xs),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: BzSpace.xs),
                  Text(
                    itemPriceLabel(item.priceTiyin),
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: BzSpace.s),
            if (qty == 0) AddButton(onPressed: onAdd) else QtyStepper(qty: qty, onDec: onDec, onInc: onAdd),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- cart bar

class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart, required this.onOpen});

  final CartState cart;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.m),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CatalogText.cartCount(cart.count),
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
                    ),
                    Text(
                      Money.format(cart.totalTiyin),
                      style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              CtaButton(label: CatalogText.viewCart, expanded: false, onPressed: onOpen),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- item sheet

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.slug, required this.item});

  final String slug;
  final Service item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  late int _qty;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final inCart = ref.read(cartProvider(widget.slug)).qtyOf(widget.item.id);
    _qty = inCart > 0 ? inCart : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final images = itemImages(item);
    final description = item.description?.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, 0, BzSpace.gutter, BzSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(BzRadius.l),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView(
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [for (final u in images) NetImage(url: u)],
                ),
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: BzSpace.s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? scheme.primary : scheme.outline,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: BzSpace.l),
          ],
          Text(item.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: BzSpace.xs),
          Text(
            itemPriceLabel(item.priceTiyin),
            style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: BzSpace.m),
            Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: BzSpace.xl),
          Center(
            child: QtyStepper(
              qty: _qty,
              min: 1,
              compact: false,
              onDec: () => setState(() => _qty--),
              onInc: () => setState(() => _qty++),
            ),
          ),
          const SizedBox(height: BzSpace.l),
          PrimaryButton(
            label: '${CatalogText.addToCart} · ${Money.format(item.priceTiyin * _qty)}',
            onPressed: () {
              ref.read(cartProvider(widget.slug).notifier).put(item, _qty);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
