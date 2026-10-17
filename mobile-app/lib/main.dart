import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_biznes/app/app.dart';
import 'package:tizbiz_biznes/core/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    // Riverpod 3 auto-retry OFF: errors surface immediately, tests stay deterministic.
    retry: (retryCount, error) => null,
    child: const TizbizApp(),
  ));
}
