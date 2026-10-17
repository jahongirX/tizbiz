import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/settings/providers.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/form_error_banner.dart';
import 'package:tizbiz_biznes/shared/widgets/section_card.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One settings section: its own form, field errors and "Saqlash" (sends only its own diff).
abstract class SettingsSectionWidget extends ConsumerStatefulWidget {
  const SettingsSectionWidget({super.key, required this.settings, this.onDirty});

  final BookingSettings settings;

  /// Reports whether the section has unsaved edits (the screen guards leaving).
  final ValueChanged<bool>? onDirty;
}

abstract class SettingsSectionState<W extends SettingsSectionWidget> extends ConsumerState<W> {
  final formKey = GlobalKey<FormState>();
  bool submitted = false;
  bool saving = false;
  Map<String, String> fieldErrors = const {};
  String? banner;
  List<Object?> _initial = const [];
  bool _dirty = false;

  /// Wire keys this section edits (422 pointers outside go to the banner).
  Set<String> get keys;

  /// Current input values, compared with the values at load/save time.
  List<Object?> snapshot();

  /// [base] with this section's (validated) inputs applied.
  BookingSettings buildEdited(BookingSettings base);

  /// Call at the end of initState.
  void markClean() {
    _initial = snapshot();
    if (_dirty) {
      _dirty = false;
      widget.onDirty?.call(false);
    }
  }

  /// Call from every input listener / onChanged.
  void changed() {
    final d = !listEquals(_initial, snapshot());
    if (d != _dirty) {
      _dirty = d;
      widget.onDirty?.call(d);
    }
    if (mounted) setState(() {});
  }

  bool get dirty => _dirty;

  Future<void> save() async {
    if (saving) return;
    setState(() {
      submitted = true;
      fieldErrors = const {};
      banner = null;
    });
    if (!(formKey.currentState?.validate() ?? false)) return;
    final edited = buildEdited(widget.settings);
    if (edited.diff(widget.settings).isEmpty) {
      markClean();
      showAppSnack(context, "O'zgarishlar yo'q");
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(bookingSettingsProvider.notifier).save(edited);
      if (!mounted) return;
      markClean();
      showAppSnack(context, 'Saqlandi');
    } catch (e) {
      if (!mounted) return;
      applyError(e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void applyError(Object e) {
    final fields = <String, String>{};
    String? text;
    if (e is ApiException && e.isValidation && e.hasFieldErrors) {
      for (final entry in e.fieldErrors.entries) {
        if (keys.contains(entry.key)) {
          fields[entry.key] = entry.value;
        } else {
          text ??= entry.value;
        }
      }
    } else {
      text = errorText(e);
    }
    setState(() {
      fieldErrors = fields;
      banner = text;
    });
  }

  Widget section({required String title, required List<Widget> children, Widget? trailing}) => SectionCard(
        title: title,
        trailing: trailing,
        child: Form(
          key: formKey,
          autovalidateMode: submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...children,
              const SizedBox(height: 12),
              FormErrorBanner(message: banner),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Trimmed text, '' -> null.
String? textOrNull(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

/// Decimal input with ',' or '.'; '' -> null.
double? parseDecimal(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
