import 'package:material_ui/material_ui.dart';

/// A confirm dialog; returns true only when the confirm button was tapped.
/// [danger] colors the confirm label with the danger color.
Future<bool> confirmDialog(
  BuildContext c, {
  required String title,
  String? message,
  String confirmLabel = 'Ha',
  String cancelLabel = 'Bekor qilish',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: c,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
          TextButton(
            style: danger ? TextButton.styleFrom(foregroundColor: scheme.error) : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
