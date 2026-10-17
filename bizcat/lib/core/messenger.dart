import 'package:material_ui/material_ui.dart';

import 'errors.dart';

/// Attached to MaterialApp.router; lets code without a BuildContext show snackbars.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows a floating snackbar with [text] (replacing the current one).
void showSnack(String text) {
  final m = scaffoldMessengerKey.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// [showSnack] with [errorText].
void showErrorSnack(Object error) => showSnack(errorText(error));
