import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Groups the whole part as you type ('150000' -> '150 000'); keeps up to 2 decimals after ',' / '.'.
class SomInputFormatter extends TextInputFormatter {
  const SomInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final sep = text.indexOf(RegExp('[.,]'));
    final wholeRaw = (sep >= 0 ? text.substring(0, sep) : text).replaceAll(RegExp(r'\D'), '');
    final whole = wholeRaw.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var out = whole.isEmpty ? '' : Money.group(int.parse(whole.length > 15 ? whole.substring(0, 15) : whole));
    if (sep >= 0) {
      final frac = text.substring(sep + 1).replaceAll(RegExp(r'\D'), '');
      out = '${out.isEmpty ? '0' : out},${frac.length > 2 ? frac.substring(0, 2) : frac}';
    }
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

/// So'm amount input: shows `Money.group`, reports tiyin (`Money.parseSomInput`) via [onChanged].
class SomField extends StatefulWidget {
  const SomField({
    super.key,
    required this.label,
    this.initialTiyin,
    required this.onChanged,
    this.required = false,
    this.errorText,
    this.helperText,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final int? initialTiyin;
  final ValueChanged<int?> onChanged;
  final bool required;
  final String? errorText;
  final String? helperText;

  /// Extra validation on the parsed tiyin value (runs after the required/format checks).
  final String? Function(int? tiyin)? validator;
  final bool enabled;

  /// '150 000' (or '150 000,5') for an initial tiyin value.
  static String formatInitial(int? tiyin) {
    if (tiyin == null) return '';
    final whole = Money.group(tiyin ~/ 100);
    final frac = (tiyin % 100).abs();
    return frac == 0 ? whole : '$whole,${frac.toString().padLeft(2, '0')}';
  }

  @override
  State<SomField> createState() => _SomFieldState();
}

class _SomFieldState extends State<SomField> {
  late final TextEditingController _controller = TextEditingController(text: SomField.formatInitial(widget.initialTiyin));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [SomInputFormatter()],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: "so'm",
          errorText: widget.errorText,
          helperText: widget.helperText,
        ),
        onChanged: (text) => widget.onChanged(Money.parseSomInput(text)),
        validator: (text) {
          final v = text?.trim() ?? '';
          if (v.isEmpty) return widget.required ? 'Summani kiriting' : widget.validator?.call(null);
          final tiyin = Money.parseSomInput(v);
          if (tiyin == null) return "Summa noto'g'ri";
          return widget.validator?.call(tiyin);
        },
      );
}
