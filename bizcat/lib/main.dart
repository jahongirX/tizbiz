import 'package:bizcat/app/app.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const BizcatApp(),
  ));
}
