import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Formats the 9 local digits as you type ('901234567' -> '90 123 45 67').
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = Phone.formatPartial(newValue.text);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Phone input with a fixed `+998` prefix. Validate with the built-in validator
/// ("Telefon raqam noto'g'ri"); send `Phone.normalize(controller.text)`.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'Telefon',
    this.errorText,
    this.required = true,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;

  /// Server-side error (e.g. 422 pointer `phone`).
  final String? errorText;
  final bool required;

  /// Replaces the default validator.
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;

  static const invalidMessage = "Telefon raqam noto'g'ri";

  /// Default validation: required -> must be valid; optional -> empty or valid.
  static String? validate(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? invalidMessage : null;
    return Phone.isValid(v) ? null : invalidMessage;
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: const [UzPhoneInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          prefixText: '+998 ',
          hintText: '90 123 45 67',
          errorText: errorText,
        ),
        validator: validator ?? (v) => validate(v, required: required),
        onChanged: onChanged,
      );
}
