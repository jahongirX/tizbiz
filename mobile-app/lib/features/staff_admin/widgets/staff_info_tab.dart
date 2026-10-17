import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/staff_admin/actions.dart';
import 'package:tizbiz_biznes/features/staff_admin/form_support.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Ism / Mutaxassislik / Komissiya % / Faol, shared by the create screen and the Ma'lumot tab.
class StaffFieldsForm extends ConsumerStatefulWidget {
  const StaffFieldsForm({super.key, this.initial, required this.submitLabel, required this.onSubmit, this.onDirtyChanged});

  final Staff? initial;
  final String submitLabel;

  /// Gets the body from `Staff.toInput()`; throws [ApiException] on failure.
  final Future<void> Function(Map<String, dynamic> body) onSubmit;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<StaffFieldsForm> createState() => _StaffFieldsFormState();
}

class _StaffFieldsFormState extends ConsumerState<StaffFieldsForm> {
  static const _pointers = {'name', 'specialization', 'commission_percent', 'is_active'};

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _spec = TextEditingController(text: widget.initial?.specialization ?? '');
  late final _commission = TextEditingController(text: '${widget.initial?.commissionPercent ?? 0}');
  late bool _active = widget.initial?.isActive ?? true;
  bool _submitted = false;
  bool _saving = false;
  bool _dirty = false;
  Map<String, String> _fieldErrors = const {};
  String? _banner;

  @override
  void dispose() {
    _name.dispose();
    _spec.dispose();
    _commission.dispose();
    super.dispose();
  }

  void _changed() {
    final i = widget.initial;
    final dirty = _name.text.trim() != (i?.name ?? '') ||
        _spec.text.trim() != (i?.specialization ?? '') ||
        _commission.text.trim() != '${i?.commissionPercent ?? 0}' ||
        _active != (i?.isActive ?? true);
    if (_fieldErrors.isNotEmpty) setState(() => _fieldErrors = const {});
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
      widget.onDirtyChanged?.call(dirty);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    final spec = _spec.text.trim();
    final body = Staff(
      id: widget.initial?.id ?? 0,
      name: _name.text.trim(),
      specialization: spec.isEmpty ? null : spec,
      isActive: _active,
      commissionPercent: int.parse(_commission.text.trim()),
    ).toInput();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(body);
      if (!mounted) return;
      setState(() => _dirty = false);
      widget.onDirtyChanged?.call(false);
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      final split = splitFormError(e, _pointers);
      setState(() {
        _fieldErrors = split.fields;
        _banner = split.banner;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 128,
            decoration: InputDecoration(labelText: 'Ism', errorText: _fieldErrors['name'], counterText: ''),
            onChanged: (_) => _changed(),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Ismni kiriting' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _spec,
            maxLength: 96,
            decoration: InputDecoration(
              labelText: 'Mutaxassislik',
              hintText: 'Masalan, sartarosh',
              errorText: _fieldErrors['specialization'],
              counterText: '',
            ),
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commission,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(
              labelText: 'Komissiya %',
              suffixText: '%',
              helperText: "Ish haqi hisobida xizmat narxidan ulush",
              errorText: _fieldErrors['commission_percent'],
            ),
            onChanged: (_) => _changed(),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 0 || n > 100) return "0 dan 100 gacha butun son kiriting";
              return null;
            },
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Faol'),
            subtitle: Text(_fieldErrors['is_active'] ?? "Nofaol xodim jadval va bron qilishda ko'rinmaydi"),
            value: _active,
            onChanged: (v) {
              setState(() => _active = v);
              _changed();
            },
          ),
          const SizedBox(height: 12),
          FormErrorBanner(message: _banner),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// Ma'lumot tab: edit fields (PATCH), login link status, deactivate.
class StaffInfoTab extends ConsumerStatefulWidget {
  const StaffInfoTab({super.key, required this.staff, this.onDirtyChanged});

  final Staff staff;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<StaffInfoTab> createState() => _StaffInfoTabState();
}

class _StaffInfoTabState extends ConsumerState<StaffInfoTab> {
  bool _busy = false;

  Future<void> _deactivate() async {
    final ok = await confirmAction(
      context,
      title: 'Xodim faolsizlantirilsinmi?',
      message: "U jadvalda va onlayn bron qilishda ko'rinmaydi. Tarix saqlanadi.",
      confirmLabel: 'Faolsizlantirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(staffActionsProvider).deactivate(widget.staff.id);
      if (mounted) showAppSnack(context, 'Xodim faolsizlantirildi');
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      showAppSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = widget.staff;
    final linked = s.userId != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StaffFieldsForm(
          key: ValueKey('staff-form-${s.id}'),
          initial: s,
          submitLabel: 'Saqlash',
          onDirtyChanged: widget.onDirtyChanged,
          onSubmit: (body) async {
            await ref.read(staffActionsProvider).update(s.id, body);
            if (context.mounted) showAppSnack(context, 'Saqlandi');
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Tizimga kirish hisobi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(linked ? Icons.link : Icons.link_off, size: 18, color: linked ? c.success : c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(linked
                        ? "Tizimga kirish hisobi: bog'langan"
                        : "Tizimga kirish hisobi: bog'lanmagan. Jamoa bo'limida bog'lang."),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go(Routes.team),
                icon: const Icon(Icons.group_outlined),
                label: const Text("Jamoa bo'limi"),
              ),
            ],
          ),
        ),
        if (s.isActive) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger)),
            onPressed: _busy ? null : () => unawaited(_deactivate()),
            icon: const Icon(Icons.person_off_outlined),
            label: const Text('Faolsizlantirish'),
          ),
        ],
      ],
    );
  }
}
