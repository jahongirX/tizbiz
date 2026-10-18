import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/data/storefront_providers.dart';
import 'package:bizcat/features/booking_catalog/copy.dart';
import 'package:bizcat/features/booking_catalog/providers.dart';
import 'package:bizcat/features/booking_catalog/widgets/catalog_widgets.dart';
import 'package:bizcat/shared/widgets/async_body.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/flow_widgets.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const String _title = 'Rasmiylashtirish';

/// `/b/:slug/checkout` (signed in): the order summary, name, note and the submit.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  bool _leaving = false;

  CheckoutController get _ctl => ref.read(checkoutControllerProvider(widget.slug).notifier);

  @override
  void initState() {
    super.initState();
    final s = ref.read(checkoutControllerProvider(widget.slug));
    _name = TextEditingController(text: s.name);
    _note = TextEditingController(text: s.note);
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(CatalogCopy copy) async {
    FocusScope.of(context).unfocus();
    final order = await _ctl.submit();
    if (!mounted) return;
    if (order != null) {
      _leaving = true;
      showSnack(copy.placed);
      context.go(AppRoutes.order(order.id, created: true));
      return;
    }
    final e = ref.read(checkoutControllerProvider(widget.slug)).error;
    if (e is ApiException && e.status == 400) {
      final dropped = await _ctl.refreshCatalog();
      if (dropped > 0) showSnack(CatalogText.itemsGone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider(widget.slug));
    final checkout = ref.watch(checkoutControllerProvider(widget.slug));
    final store = ref.watch(storefrontProvider(widget.slug));

    if (cart.isEmpty && checkout.placed == null && !checkout.submitting) {
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(AppRoutes.menu(widget.slug));
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text(_title)),
        body: const LoadingView(),
      );
    }

    final copy = CatalogCopy.forEngine(store.value?.engine);
    return Scaffold(
      appBar: AppBar(title: const Text(_title)),
      bottomNavigationBar: store.hasValue
          ? BottomActionBar(
              child: CtaButton(
                label: copy.submit,
                loading: checkout.submitting,
                onPressed: checkout.placed == null ? () => unawaited(_submit(copy)) : null,
              ),
            )
          : null,
      body: AsyncBody<StorefrontData>(
        value: store,
        onRetry: () => ref.invalidate(storefrontProvider(widget.slug)),
        builder: (data) => _CheckoutForm(
          store: data,
          cart: cart,
          state: checkout,
          copy: copy,
          name: _name,
          note: _note,
          onName: _ctl.setName,
          onNote: _ctl.setNote,
          onRetry: () => unawaited(_submit(copy)),
        ),
      ),
    );
  }
}

class _CheckoutForm extends ConsumerWidget {
  const _CheckoutForm({
    required this.store,
    required this.cart,
    required this.state,
    required this.copy,
    required this.name,
    required this.note,
    required this.onName,
    required this.onNote,
    required this.onRetry,
  });

  final StorefrontData store;
  final CartState cart;
  final CheckoutState state;
  final CatalogCopy copy;
  final TextEditingController name;
  final TextEditingController note;
  final ValueChanged<String> onName;
  final ValueChanged<String> onNote;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final business = store.business;
    final consumer = ref.watch(currentConsumerProvider);
    final error = state.error;
    final hasFieldErrors = state.fieldErrors.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxxl),
      children: [
        BusinessMiniHeader(
          name: business.name,
          logo: business.logo,
          brandColor: business.brandColor,
          subtitle: business.address,
        ),
        const SizedBox(height: BzSpace.l),
        SummaryCard(
          rows: [
            for (final l in cart.lines.values)
              SummaryRow(label: '${l.item.name} ×${l.qty}', value: Money.format(l.totalTiyin)),
            SummaryRow(label: CatalogText.total, value: Money.format(cart.totalTiyin), emphasize: true),
          ],
        ),
        const SizedBox(height: BzSpace.xl),
        TextField(
          key: const ValueKey('checkout-name-field'),
          controller: name,
          onChanged: onName,
          enabled: !state.submitting,
          maxLength: kNameMax,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: CatalogText.nameLabel,
            counterText: '',
            errorText: state.fieldErrors['name'],
          ),
        ),
        if (consumer != null) ...[
          const SizedBox(height: BzSpace.s),
          Text('Telefon: ${Phone.format(consumer.phone)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: BzSpace.xs),
          Text(CatalogText.phoneNote, style: muted),
        ],
        const SizedBox(height: BzSpace.l),
        TextField(
          key: const ValueKey('checkout-note-field'),
          controller: note,
          onChanged: onNote,
          enabled: !state.submitting,
          maxLength: kNoteMax,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: CatalogText.noteLabel,
            hintText: CatalogText.noteHint,
            alignLabelWithHint: true,
            errorText: state.fieldErrors['note'],
          ),
        ),
        const SizedBox(height: BzSpace.m),
        NoticeCard(icon: BzIcons.shop, text: copy.pickupNote),
        if (error != null && !hasFieldErrors) ...[
          const SizedBox(height: BzSpace.l),
          _SubmitAlert(error: error, phone: business.phone, onRetry: onRetry),
        ],
      ],
    );
  }
}

class _SubmitAlert extends ConsumerWidget {
  const _SubmitAlert({required this.error, required this.phone, required this.onRetry});

  final Object error;
  final String? phone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    if (e is ApiException && e.isForbidden) {
      final canCall = Phone.telUri(phone) != null;
      return CatalogAlert(
        message: e.message.trim().isEmpty ? CatalogText.ordersClosed : e.message,
        action: canCall
            ? SecondaryButton(
                label: CatalogText.call,
                icon: BzIcons.call,
                onPressed: () => unawaited(callPhone(ref, phone)),
              )
            : null,
      );
    }
    if (e is ApiException && e.isNotFound) return const CatalogAlert(message: 'Biznes topilmadi.');
    if (e is ApiException && (e.status == 400 || e.status == 422)) return CatalogAlert(message: e.message);
    return CatalogAlert(
      message: errorText(e),
      action: SecondaryButton(label: 'Qayta urinish', icon: BzIcons.refresh, onPressed: onRetry),
    );
  }
}
