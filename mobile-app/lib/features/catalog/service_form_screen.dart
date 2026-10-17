import 'dart:async';
import 'dart:convert' show jsonEncode;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/catalog/actions.dart';
import 'package:tizbiz_biznes/features/catalog/form_support.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/som_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Create ([serviceId] null) or edit a service / menu item / rental item.
class ServiceFormScreen extends ConsumerWidget {
  const ServiceFormScreen({super.key, this.serviceId});

  final int? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(activeBusinessProvider)?.engine ?? Engine.slot;
    final categories = ref.watch(serviceCategoriesProvider).value ?? const <ServiceCategory>[];
    final id = serviceId;
    if (id == null) return _ServiceForm(engine: engine, categories: categories);
    final async = ref.watch(servicesListProvider);
    Service? service;
    for (final s in async.value ?? const <Service>[]) {
      if (s.id == id) service = s;
    }
    if (service != null) {
      return _ServiceForm(key: ValueKey('service-$id'), engine: engine, categories: categories, initial: service);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Xizmat')),
      body: AsyncBody<List<Service>>(
        value: async,
        onRetry: () => ref.invalidate(servicesListProvider),
        isEmpty: (_) => service == null,
        empty: const EmptyView(icon: Icons.search_off, title: 'Topilmadi.', message: "Bu xizmat o'chirilgan bo'lishi mumkin."),
        data: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _ServiceForm extends ConsumerStatefulWidget {
  const _ServiceForm({super.key, required this.engine, required this.categories, this.initial});

  final Engine engine;
  final List<ServiceCategory> categories;
  final Service? initial;

  @override
  ConsumerState<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<_ServiceForm> {
  static const _pointers = {
    'name',
    'category_id',
    'duration_min',
    'price_tiyin',
    'deposit_tiyin',
    'is_active',
    'online_bookable',
    'description',
  };

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _duration = TextEditingController(text: '${widget.initial?.durationMin ?? 30}');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late int? _categoryId = widget.initial?.categoryId;
  late int? _price = widget.initial?.priceTiyin;
  late int? _deposit = widget.initial?.depositTiyin;
  late bool _active = widget.initial?.isActive ?? true;
  late bool _online = widget.initial?.onlineBookable ?? true;
  late final String _initialBody = widget.initial == null ? '' : jsonEncode(_body());
  bool _submitted = false;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  String? _banner;
  bool _saved = false;

  bool get _isCatalog => widget.engine == Engine.catalog;
  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() {
    final i = widget.initial;
    final desc = _description.text.trim();
    return Service(
      id: i?.id ?? 0,
      name: _name.text.trim(),
      categoryId: _categoryId,
      // Catalog hides duration / online booking but still sends the current value.
      durationMin: _isCatalog ? (i?.durationMin ?? 30) : (int.tryParse(_duration.text.trim()) ?? 30),
      priceTiyin: _price ?? 0,
      depositTiyin: _deposit,
      isActive: _active,
      onlineBookable: _isCatalog ? (i?.onlineBookable ?? true) : _online,
      image: i?.image,
      description: desc.isEmpty ? null : desc,
      gallery: i?.gallery ?? const [],
    ).toInput();
  }

  bool get _dirty {
    if (_saved) return false;
    if (_isEdit) return jsonEncode(_body()) != _initialBody;
    return _name.text.trim().isNotEmpty || _price != null || _description.text.trim().isNotEmpty;
  }

  void _touch() => setState(() => _fieldErrors = const {});

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.services);
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await confirmAction(context,
        title: "O'zgarishlar saqlanmaydi. Chiqasizmi?", confirmLabel: 'Chiqish', destructive: true);
    if (ok && mounted) {
      setState(() => _saved = true);
      _leave();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final actions = ref.read(catalogActionsProvider);
    try {
      final body = _body();
      if (_isEdit) {
        await actions.updateService(widget.initial!.id, body);
      } else {
        await actions.createService(body);
      }
      if (!mounted) return;
      setState(() => _saved = true);
      showAppSnack(context, _isEdit ? 'Saqlandi' : "Qo'shildi");
      _leave();
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      final split = splitFormError(e, _pointers);
      setState(() {
        _fieldErrors = split.fields;
        _banner = split.banner;
        _saving = false;
      });
    }
  }

  Future<void> _deactivate() async {
    final s = widget.initial!;
    final ok = await confirmAction(
      context,
      title: 'Faolsizlantirilsinmi?',
      message: "«${s.name}» mijozlarga ko'rinmaydi va bron qilinmaydi. Keyin qayta faollashtirish mumkin.",
      confirmLabel: 'Faolsizlantirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(catalogActionsProvider).deactivateService(s.id);
      if (!mounted) return;
      setState(() => _saved = true);
      showAppSnack(context, 'Faolsizlantirildi');
      _leave();
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      setState(() => _saving = false);
      showAppSnack(context, splitFormError(e, const {}).banner ?? 'Xatolik yuz berdi.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final i = widget.initial;
    final cats = widget.categories;
    final catValue = cats.any((x) => x.id == _categoryId) ? _categoryId : null;
    final depositTooBig = (_deposit ?? 0) > 0 && _price != null && _deposit! > _price!;
    final form = MaxWidth(
      child: Form(
        key: _form,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 128,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Nomi', errorText: _fieldErrors['name'], counterText: ''),
              onChanged: (_) => _touch(),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nomini kiriting' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: ValueKey('cat-${cats.length}'),
              initialValue: catValue,
              decoration: InputDecoration(labelText: 'Kategoriya', errorText: _fieldErrors['category_id']),
              items: [
                const DropdownMenuItem<int?>(child: Text('Kategoriyasiz')),
                for (final cat in cats) DropdownMenuItem<int?>(value: cat.id, child: Text(cat.name)),
              ],
              onChanged: (v) => setState(() {
                _categoryId = v;
                _fieldErrors = const {};
              }),
            ),
            if (!_isCatalog) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(
                  labelText: 'Davomiyligi, daqiqa',
                  suffixText: 'daq',
                  errorText: _fieldErrors['duration_min'],
                ),
                onChanged: (_) => _touch(),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n == null || n < 1 || n > 1440 ? '1 dan 1440 gacha daqiqa kiriting' : null;
                },
              ),
            ],
            const SizedBox(height: 12),
            SomField(
              label: 'Narxi',
              required: true,
              initialTiyin: i?.priceTiyin,
              errorText: _fieldErrors['price_tiyin'],
              onChanged: (v) => setState(() {
                _price = v;
                _fieldErrors = const {};
              }),
            ),
            const SizedBox(height: 12),
            SomField(
              label: "Oldindan to'lov",
              initialTiyin: i?.depositTiyin,
              errorText: _fieldErrors['deposit_tiyin'],
              helperText: depositTooBig ? "Diqqat: oldindan to'lov narxdan katta" : "No-show'ni kamaytiradi",
              onChanged: (v) => setState(() {
                _deposit = v;
                _fieldErrors = const {};
              }),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Faol'),
              subtitle: _fieldErrors['is_active'] == null ? null : Text(_fieldErrors['is_active']!, style: TextStyle(color: c.danger)),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (!_isCatalog)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Onlayn bron qilish mumkin'),
                subtitle: Text(_fieldErrors['online_bookable'] ?? "O'chirilsa, faqat admin yozib qo'yadi"),
                value: _online,
                onChanged: (v) => setState(() => _online = v),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Tavsif',
                alignLabelWithHint: true,
                errorText: _fieldErrors['description'],
              ),
              onChanged: (_) => _touch(),
            ),
            if (i?.image != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: i!.image!,
                  height: 160,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(height: 160, color: c.surface2),
                ),
              ),
              const SizedBox(height: 6),
              Text('Rasmni web kabinetda o\'zgartiring', style: TextStyle(color: c.textMuted, fontSize: 12)),
            ] else ...[
              const SizedBox(height: 12),
              Text("Rasm yo'q. Rasmni web kabinetda qo'shing.", style: TextStyle(color: c.textMuted, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            FormErrorBanner(message: _banner),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_submit()),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Saqlash' : "Qo'shish"),
            ),
            if (_isEdit && i!.isActive) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger)),
                onPressed: _saving ? null : () => unawaited(_deactivate()),
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Faolsizlantirish'),
              ),
            ],
          ],
        ),
      ),
    );
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? i!.name : _newTitle(widget.engine))),
        body: form,
      ),
    );
  }
}

String _newTitle(Engine e) => switch (e) {
      Engine.catalog => 'Yangi pozitsiya',
      Engine.rental => 'Yangi buyum',
      _ => 'Yangi xizmat',
    };
