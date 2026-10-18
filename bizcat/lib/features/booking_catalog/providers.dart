import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/revisions.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'copy.dart';

const Object _keep = Object();

/// Highest quantity of one line (the stepper stops there).
const int kMaxLineQty = 99;

// ---------------------------------------------------------------------------------------------
// Menu sections
// ---------------------------------------------------------------------------------------------

/// One menu section: a category (id 0 = `Boshqa`) and its items.
@immutable
final class CatalogSection {
  const CatalogSection({required this.id, required this.name, required this.items});

  final int id;
  final String name;
  final List<Service> items;
}

/// The menu as sections, in server order. Categories without items are dropped; items that no
/// category lists are gathered in a trailing `Boshqa` section (merged with a server id-0 one).
List<CatalogSection> catalogSections(StorefrontData s) {
  final sections = <CatalogSection>[];
  final seen = <int>{};
  final other = <Service>[];
  for (final c in s.categories) {
    final items = [
      for (final i in c.items)
        if (seen.add(i.id)) i,
    ];
    if (items.isEmpty) continue;
    if (c.id == 0) {
      other.addAll(items);
      continue;
    }
    final name = c.name.trim().isEmpty ? CatalogText.other : c.name.trim();
    sections.add(CatalogSection(id: c.id, name: name, items: items));
  }
  for (final i in s.items) {
    if (seen.add(i.id)) other.add(i);
  }
  if (other.isNotEmpty) sections.add(CatalogSection(id: 0, name: CatalogText.other, items: other));
  return sections;
}

/// Every orderable item of the storefront by id (categories and the flat `items` list).
Map<int, Service> catalogItemsById(StorefrontData s) => {
  for (final c in s.categories)
    for (final i in c.items) i.id: i,
  for (final i in s.items) i.id: i,
};

/// The images of an item for the detail sheet: `image` first, then `gallery`, deduplicated.
List<String> itemImages(Service item) {
  final out = <String>[];
  for (final u in [item.image, ...item.gallery]) {
    final t = u?.trim();
    if (t != null && t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Cart
// ---------------------------------------------------------------------------------------------

/// One cart line: the item snapshot from the storefront and its quantity.
@immutable
final class CartLine {
  const CartLine({required this.item, required this.qty});

  final Service item;
  final int qty;

  int get totalTiyin => item.priceTiyin * qty;

  CartLine withQty(int q) => CartLine(item: item, qty: q);
}

/// The cart of one business. [lines] keeps insertion order.
@immutable
final class CartState {
  const CartState({this.lines = const {}});

  final Map<int, CartLine> lines;

  /// Units in the cart (2 x Napoleon = 2).
  int get count => lines.values.fold(0, (s, l) => s + l.qty);
  int get totalTiyin => lines.values.fold(0, (s, l) => s + l.totalTiyin);
  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int qtyOf(int serviceId) => lines[serviceId]?.qty ?? 0;

  /// The POST body lines, in cart order.
  List<OrderLine> toOrderLines() => [for (final l in lines.values) OrderLine(l.item.id, l.qty)];

  /// 'id:qty,id:qty' — changes whenever what would be ordered changes.
  String get signature => [for (final l in lines.values) '${l.item.id}:${l.qty}'].join(',');
}

/// The cart per business slug. Not auto-disposed: it survives menu -> cart -> checkout ->
/// login and back.
final cartProvider = NotifierProvider.family<CartController, CartState, String>(CartController.new);

class CartController extends Notifier<CartState> {
  CartController(this.slug);

  final String slug;

  /// Order ids whose `?reorder=` has already been applied to this cart.
  final Set<int> _appliedReorders = {};

  @override
  CartState build() => const CartState();

  void _emit(Map<int, CartLine> lines) => state = CartState(lines: Map.unmodifiable(lines));

  /// One more of [item] (a new line goes to the end).
  void add(Service item) => put(item, state.qtyOf(item.id) + 1);

  /// One less; the line is removed at 0.
  void dec(int serviceId) => setQty(serviceId, state.qtyOf(serviceId) - 1);

  /// Sets the quantity of an existing line (0 removes it; clamped to [kMaxLineQty]).
  void setQty(int serviceId, int qty) {
    final line = state.lines[serviceId];
    if (line == null) return;
    put(line.item, qty);
  }

  /// Sets [item] to [qty] (0 removes it; clamped to [kMaxLineQty]); refreshes the snapshot.
  void put(Service item, int qty) {
    final q = qty > kMaxLineQty ? kMaxLineQty : qty;
    final next = Map<int, CartLine>.of(state.lines);
    if (q <= 0) {
      if (next.remove(item.id) == null) return;
    } else {
      next[item.id] = CartLine(item: item, qty: q);
    }
    _emit(next);
  }

  void remove(int serviceId) {
    if (!state.lines.containsKey(serviceId)) return;
    _emit(Map<int, CartLine>.of(state.lines)..remove(serviceId));
  }

  void clear() {
    if (state.isEmpty) return;
    state = const CartState();
  }

  /// Replaces the line snapshots with the storefront's current items and drops the lines whose
  /// item is gone. Returns the number of dropped lines.
  int sync(StorefrontData s) {
    final byId = catalogItemsById(s);
    var dropped = 0;
    final next = <int, CartLine>{};
    for (final l in state.lines.values) {
      final fresh = byId[l.item.id];
      if (fresh == null) {
        dropped++;
      } else {
        next[fresh.id] = CartLine(item: fresh, qty: l.qty);
      }
    }
    _emit(next);
    return dropped;
  }

  /// True the first time it is called for [orderId] (the menu applies a reorder only once).
  bool markReorder(int orderId) => _appliedReorders.add(orderId);

  /// Fills the cart from a past [order]: its lines whose item still exists in [s] replace the
  /// cart (at the current price). Returns the number of skipped order lines. When nothing is
  /// available any more the cart stays as it was.
  Future<int> applyReorder(Order order, StorefrontData s) async {
    final byId = catalogItemsById(s);
    var skipped = 0;
    final next = <int, CartLine>{};
    for (final it in order.items) {
      final item = it.serviceId == null ? null : byId[it.serviceId];
      if (item == null || it.qty <= 0) {
        skipped++;
        continue;
      }
      final q = (next[item.id]?.qty ?? 0) + it.qty;
      next[item.id] = CartLine(item: item, qty: q > kMaxLineQty ? kMaxLineQty : q);
    }
    if (next.isNotEmpty) _emit(next);
    return skipped;
  }
}

/// GET Endpoints.consumerOrder(id) -> the order behind `?reorder=`. Signed out -> null (the
/// reorder is skipped).
final reorderSourceProvider = FutureProvider.autoDispose.family<Order?, int>((ref, id) async {
  final consumerId = ref.watch(consumerIdProvider);
  if (consumerId == null) return null;
  return ref
      .read(apiProvider)
      .get<Order>(Endpoints.consumerOrder(id), decode: (d) => Order.fromJson(JsonRead.object(d)));
});

// ---------------------------------------------------------------------------------------------
// Checkout
// ---------------------------------------------------------------------------------------------

/// The checkout form and the submit state.
@immutable
final class CheckoutState {
  const CheckoutState({
    this.name = '',
    this.note = '',
    this.idempotencyKey,
    this.submitting = false,
    this.error,
    this.fieldErrors = const {},
    this.placed,
  });

  final String name;
  final String note;

  /// Created on first open, reused on retry, replaced when the cart changes.
  final String? idempotencyKey;
  final bool submitting;

  /// The last submit failure (ApiException or another error).
  final Object? error;

  /// Inline errors by field ('name', 'note'): local validation or a 422 pointer.
  final Map<String, String> fieldErrors;

  /// The created order (the cart has been cleared).
  final Order? placed;

  CheckoutState copyWith({
    String? name,
    String? note,
    Object? idempotencyKey = _keep,
    bool? submitting,
    Object? error = _keep,
    Map<String, String>? fieldErrors,
    Object? placed = _keep,
  }) => CheckoutState(
    name: name ?? this.name,
    note: note ?? this.note,
    idempotencyKey: identical(idempotencyKey, _keep) ? this.idempotencyKey : idempotencyKey as String?,
    submitting: submitting ?? this.submitting,
    error: identical(error, _keep) ? this.error : error,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    placed: identical(placed, _keep) ? this.placed : placed as Order?,
  );
}

/// The form fields a 422 pointer can point at.
const Set<String> kCheckoutFields = {'name', 'note'};

/// Max lengths of the form (BP: name 2..64 when given, note max 500).
const int kNameMin = 2, kNameMax = 64, kNoteMax = 500;

final checkoutControllerProvider = NotifierProvider.autoDispose.family<CheckoutController, CheckoutState, String>(
  CheckoutController.new,
);

class CheckoutController extends Notifier<CheckoutState> {
  CheckoutController(this.slug);

  final String slug;

  @override
  CheckoutState build() {
    ref.listen<CartState>(cartProvider(slug), (prev, next) {
      if (prev?.signature != next.signature) {
        state = state.copyWith(idempotencyKey: Idempotency.newKey());
      }
    });
    final consumer = ref.read(currentConsumerProvider);
    return CheckoutState(name: consumer?.name?.trim() ?? '', idempotencyKey: Idempotency.newKey());
  }

  void setName(String v) {
    if (v == state.name) return;
    final errors = Map<String, String>.of(state.fieldErrors)..remove('name');
    state = state.copyWith(name: v, fieldErrors: errors);
  }

  void setNote(String v) {
    if (v == state.note) return;
    final errors = Map<String, String>.of(state.fieldErrors)..remove('note');
    state = state.copyWith(note: v, fieldErrors: errors);
  }

  /// Local checks: name 2..64 when not empty, note at most 500.
  Map<String, String> validate() {
    final errors = <String, String>{};
    final name = state.name.trim();
    if (name.isNotEmpty && (name.length < kNameMin || name.length > kNameMax)) {
      errors['name'] = CatalogText.nameError;
    }
    if (state.note.trim().length > kNoteMax) errors['note'] = CatalogText.noteError;
    return errors;
  }

  /// POST Endpoints.consumerOrders with the Idempotency-Key. Success: the cart is cleared,
  /// bookings are bumped and the order is returned (also in [CheckoutState.placed]). Failure:
  /// null, with [CheckoutState.error] / [CheckoutState.fieldErrors] set. The key stays, so a
  /// retry after a network error replays the same request.
  Future<Order?> submit() async {
    if (state.submitting || state.placed != null) return null;
    final cart = ref.read(cartProvider(slug));
    if (cart.isEmpty) return null;
    final local = validate();
    if (local.isNotEmpty) {
      state = state.copyWith(fieldErrors: local, error: null);
      return null;
    }
    final key = state.idempotencyKey ?? Idempotency.newKey();
    final name = state.name.trim();
    final note = state.note.trim();
    final request = ConsumerOrderRequest(
      slug: slug,
      items: cart.toOrderLines(),
      note: note.isEmpty ? null : note,
      name: name.isEmpty ? null : name,
    );
    final api = ref.read(apiProvider);
    final cartCtl = ref.read(cartProvider(slug).notifier);
    final revision = ref.read(bookingsRevisionProvider.notifier);
    state = state.copyWith(submitting: true, error: null, fieldErrors: const {}, idempotencyKey: key);
    try {
      final order = await api.post<Order>(
        Endpoints.consumerOrders,
        body: request.toJson(),
        idempotencyKey: key,
        decode: (d) => Order.fromJson(JsonRead.object(d)),
      );
      if (ref.mounted) state = state.copyWith(submitting: false, placed: order);
      cartCtl.clear();
      revision.bump();
      return order;
    } on ApiException catch (e) {
      if (ref.mounted) {
        final fields = {
          for (final f in e.fieldErrors.entries)
            if (kCheckoutFields.contains(f.key)) f.key: f.value,
        };
        state = state.copyWith(submitting: false, error: e, fieldErrors: fields);
      }
      return null;
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(submitting: false, error: e);
      return null;
    }
  }

  /// After a 400 (`Savat bo'sh.` / `Mahsulotlar topilmadi.`): refetches the storefront and drops
  /// the cart lines whose item is gone. Returns the number of dropped lines (0 on failure).
  Future<int> refreshCatalog() async {
    final cartCtl = ref.read(cartProvider(slug).notifier);
    ref.invalidate(storefrontProvider(slug));
    try {
      final s = await ref.read(storefrontProvider(slug).future);
      return cartCtl.sync(s);
    } on Object {
      return 0;
    }
  }

  /// Clears the shown error (after its dialog was closed).
  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }
}
