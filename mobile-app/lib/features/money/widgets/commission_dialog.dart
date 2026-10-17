import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Validates a commission input: an integer 0..100.
String? validateCommission(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return 'Komissiyani kiriting';
  final v = int.tryParse(t);
  if (v == null || v < 0 || v > 100) return '0 dan 100 gacha butun son kiriting';
  return null;
}

/// Edits one staff member's commission %; [onSubmit] saves it. Pops `true` after a save.
class CommissionDialog extends StatefulWidget {
  const CommissionDialog({super.key, required this.staffName, required this.initial, required this.onSubmit});

  final String staffName;
  final int initial;
  final Future<void> Function(int percent) onSubmit;

  static Future<bool?> show(
    BuildContext context, {
    required String staffName,
    required int initial,
    required Future<void> Function(int percent) onSubmit,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => CommissionDialog(staffName: staffName, initial: initial, onSubmit: onSubmit),
      );

  @override
  State<CommissionDialog> createState() => _CommissionDialogState();
}

class _CommissionDialogState extends State<CommissionDialog> {
  final _form = GlobalKey<FormState>();
  late final _ctrl = TextEditingController(text: '${widget.initial}');
  bool _submitted = false;
  bool _saving = false;
  String? _fieldError;
  String? _formError;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _fieldError = null;
      _formError = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(int.parse(_ctrl.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldError = e.fieldErrors['commission_percent'];
        _formError = _fieldError == null ? e.message : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = 'Xatolik yuz berdi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Komissiya'),
      content: Form(
        key: _form,
        autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.staffName),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: InputDecoration(labelText: 'Komissiya', suffixText: '%', errorText: _fieldError),
              validator: validateCommission,
              onFieldSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              FormErrorBanner(message: _formError),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Bekor')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}
