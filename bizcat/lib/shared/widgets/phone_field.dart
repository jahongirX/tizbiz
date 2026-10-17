import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Formats the 9 local digits as-you-type ('90 123 45 67'); a pasted '+998...' is accepted.
final class LocalPhoneFormatter extends TextInputFormatter {
  const LocalPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = Phone.formatPartial(newValue.text);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Digits (max 9) of a [PhoneField] controller text: '90 123 45 67' -> '901234567'.
String phoneFieldDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

/// '+998XXXXXXXXX' from a [PhoneField] controller text, or null when not 9 valid digits.
String? phoneFieldNormalized(String text) {
  final d = phoneFieldDigits(text);
  if (d.length != 9 || !Phone.isValid('998$d')) return null;
  return Phone.normalize('998$d');
}

/// Phone input with a fixed `+998` prefix. The controller text is the formatted local part;
/// callers use `Phone.normalize('998' + digits)` (or [phoneFieldNormalized]).
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: const [LocalPhoneFormatter()],
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: 'Telefon raqam',
        hintText: '90 123 45 67',
        errorText: errorText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text('+998', style: theme.textTheme.bodyLarge),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
  }
}
