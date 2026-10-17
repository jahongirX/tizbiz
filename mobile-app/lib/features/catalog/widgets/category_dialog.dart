import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/catalog/actions.dart';
import 'package:tizbiz_biznes/features/catalog/form_support.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Add (null [category]) or edit a service category; pops with the saved row.
class CategoryDialog extends ConsumerStatefulWidget {
  const CategoryDialog({super.key, this.category, this.nextSort = 0});

  final ServiceCategory? category;

  /// Default Tartib for a new category.
  final int nextSort;

  static Future<ServiceCategory?> show(BuildContext context, {ServiceCategory? category, int nextSort = 0}) =>
      showDialog<ServiceCategory>(context: context, builder: (_) => CategoryDialog(category: category, nextSort: nextSort));

  @override
  ConsumerState<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _sort = TextEditingController(text: '${widget.category?.sort ?? widget.nextSort}');
  bool _saving = false;
  bool _submitted = false;
  Map<String, String> _fieldErrors = const {};
  String? _banner;

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _banner = null;
      _fieldErrors = const {};
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final sort = int.parse(_sort.text.trim());
    setState(() => _saving = true);
    try {
      final actions = ref.read(catalogActionsProvider);
      final c = widget.category;
      final saved = c == null
          ? await actions.createCategory(name: name, sort: sort)
          : await actions.updateCategory(c.id, name: name, sort: sort);
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      reportForbidden(ref, e);
      final split = splitFormError(e, const {'name', 'sort'});
      setState(() {
        _fieldErrors = split.fields;
        _banner = split.banner;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Yangi kategoriya' : 'Kategoriyani tahrirlash'),
      content: Form(
        key: _form,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 96,
              decoration: InputDecoration(labelText: 'Nomi', errorText: _fieldErrors['name'], counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nomini kiriting' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sort,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              decoration: InputDecoration(
                labelText: 'Tartib',
                helperText: 'Kichik raqam yuqorida turadi',
                errorText: _fieldErrors['sort'],
              ),
              validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Butun son kiriting' : null,
            ),
            const SizedBox(height: 12),
            FormErrorBanner(message: _banner),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Bekor')),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_submit()),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}
