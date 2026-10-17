import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The router's current location ('/b/shox-barber?tab=reviews'), for `from` parameters.
String currentLocation(BuildContext context) {
  try {
    return GoRouter.of(context).state.uri.toString();
  } on Object {
    return '/home';
  }
}

/// Pops when possible, else goes to [fallback] (default '/home').
void popOrGo(BuildContext context, [String fallback = '/home']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
