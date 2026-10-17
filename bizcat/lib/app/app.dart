import 'dart:async';

import 'package:bizcat/app/router.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The root widget: MaterialApp.router with the Bizcat themes, the router and the messenger key.
class BizcatApp extends ConsumerStatefulWidget {
  const BizcatApp({super.key, this.googleFonts = true});

  /// Tests pass false (no runtime font fetching).
  final bool googleFonts;

  @override
  ConsumerState<BizcatApp> createState() => _BizcatAppState();
}

class _BizcatAppState extends ConsumerState<BizcatApp> {
  late final AppLifecycleListener _lifecycle;
  late ThemeData _light;
  late ThemeData _dark;

  @override
  void initState() {
    super.initState();
    _buildThemes();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void didUpdateWidget(BizcatApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.googleFonts != widget.googleFonts) _buildThemes();
  }

  void _buildThemes() {
    _light = AppTheme.light(googleFonts: widget.googleFonts);
    _dark = AppTheme.dark(googleFonts: widget.googleFonts);
  }

  /// A session restored offline (stale) refreshes the profile when the app comes back.
  void _onResume() {
    final s = ref.read(sessionProvider);
    if (s is SessionSignedIn && s.stale) {
      unawaited(ref.read(sessionProvider.notifier).refreshProfile());
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bizcat',
      routerConfig: ref.watch(routerProvider),
      theme: _light,
      darkTheme: _dark,
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
