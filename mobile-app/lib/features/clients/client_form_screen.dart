import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/core/clock.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/clients/actions.dart';
import 'package:tizbiz_biznes/features/clients/providers.dart';
import 'package:tizbiz_biznes/features/clients/widgets/tags_input.dart';
import 'package:tizbiz_biznes/shared/format.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/max_width.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateClientName(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Ismni kiriting';
  if (s.length > 128) return 'Ism 128 belgidan oshmasligi kerak';
  return null;
}

String? validateClientEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  return _emailPattern.hasMatch(s) ? null : "Email noto'g'ri";
}

String? validateBirthday(LocalDate? d, LocalDate today) =>
    d != null && d.isAfter(today) ? "Tug'ilgan kun kelajakda bo'lishi mumkin emas" : null;

/// Create / edit a client (BIZNES-SPEC §9.6).
class ClientFormScreen extends ConsumerWidget {
  const ClientFormScreen({super.key, this.clientId});

  final int? clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = clientId;
    if (id == null) return const _ClientForm(initial: null);
    final value = ref.watch(clientDetailProvider(id));
    // Keep the form once loaded: a background refetch must not reset the user's edits.
    if (value.hasValue) return _ClientForm(key: ValueKey(id), initial: value.requireValue.client);
    return Scaffold(
      appBar: AppBar(title: const Text('Mijozni tahrirlash')),
      body: AsyncBody<ClientDetail>(
        value: value,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () => ref.invalidate(clientDetailProvider(id)),
        data: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({super.key, required this.initial});

  final Client? initial;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _phone = TextEditingController(
    text: widget.initial == null ? '' : Phone.formatLocal(widget.initial!.phone),
  );
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late LocalDate? _birthday = widget.initial?.birthday;
  late List<String> _tags = [...?widget.initial?.tags];

  bool _submitted = false;
  bool _saving = false;
  bool _dirty = false;
  String? _banner;
  Map<String, String> _fieldErrors = const {};

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _phone, _email, _notes]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  LocalDate get _today => bizToday(ref.read(clockProvider), ref.read(activeBusinessProvider));

  Future<void> _pickBirthday() async {
    final today = _today;
    final initial = _birthday != null && !_birthday!.isAfter(today) ? _birthday! : LocalDate(today.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('uz'),
      initialDate: initial.toUtcMidnight(),
      firstDate: DateTime.utc(1900),
      lastDate: today.toUtcMidnight(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _birthday = LocalDate.fromDateTime(picked);
        _dirty = true;
      });
    }
  }

  Map<String, dynamic> _body() {
    final email = _email.text.trim();
    final notes = _notes.text.trim();
    return Client(
      id: widget.initial?.id ?? 0,
      name: _name.text.trim(),
      phone: Phone.normalize(_phone.text) ?? _phone.text.trim(),
      email: email.isEmpty ? null : email,
      birthday: _birthday,
      notes: notes.isEmpty ? null : notes,
      tags: _tags,
    ).toInput();
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    final ok = _form.currentState?.validate() ?? false;
    if (!ok || validateBirthday(_birthday, _today) != null) return;
    setState(() => _saving = true);
    try {
      final actions = ref.read(clientActionsProvider);
      final saved = _isEdit ? await actions.update(widget.initial!.id, _body()) : await actions.create(_body());
      if (!mounted) return;
      _dirty = false;
      showAppSnack(context, _isEdit ? 'Mijoz saqlandi' : "Mijoz qo'shildi");
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement(Routes.client(saved.id));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation && e.hasFieldErrors) {
          const known = {'name', 'phone', 'email', 'birthday', 'notes', 'tags'};
          _fieldErrors = e.fieldErrors;
          final rest = [
            for (final en in e.fieldErrors.entries)
              if (!known.contains(en.key) && !en.key.startsWith('tags')) en.value,
          ];
          _banner = rest.isEmpty ? null : rest.join('\n');
        } else {
          _banner = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) return;
    final leave = await confirmAction(
      context,
      title: "O'zgarishlar saqlanmaydi. Chiqasizmi?",
      confirmLabel: 'Chiqish',
      destructive: true,
    );
    if (leave && mounted) {
      setState(() => _dirty = false);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.clients);
      }
    }
  }

  String? _tagsError() {
    for (final e in _fieldErrors.entries) {
      if (e.key == 'tags' || e.key.startsWith('tags[')) return e.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final birthdayError = _submitted ? validateBirthday(_birthday, _today) : null;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) => _onPop(didPop),
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Mijozni tahrirlash' : 'Yangi mijoz')),
        body: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: MaxWidth(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 128,
                  decoration: InputDecoration(labelText: 'Ism', counterText: '', errorText: _fieldErrors['name']),
                  validator: validateClientName,
                ),
                const SizedBox(height: 12),
                PhoneField(controller: _phone, errorText: _fieldErrors['phone']),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: 'Email', errorText: _fieldErrors['email']),
                  validator: validateClientEmail,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthday,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Tug'ilgan kun",
                      errorText: birthdayError ?? _fieldErrors['birthday'],
                      suffixIcon: _birthday == null
                          ? const Icon(Icons.cake_outlined)
                          : IconButton(
                              tooltip: 'Tozalash',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _birthday = null;
                                _dirty = true;
                              }),
                            ),
                    ),
                    child: Text(_birthday == null ? 'Tanlanmagan' : UzDates.dayMonthYear(_birthday!)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(labelText: 'Izoh', errorText: _fieldErrors['notes']),
                ),
                const SizedBox(height: 12),
                TagsInput(
                  tags: _tags,
                  errorText: _tagsError(),
                  onChanged: (v) => setState(() {
                    _tags = v;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 16),
                if (_banner != null) ...[FormErrorBanner(message: _banner), const SizedBox(height: 12)],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Saqlash'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
