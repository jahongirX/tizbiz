import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/router.dart';
import 'package:tizbiz_biznes/app/theme/app_theme.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/theme_mode.dart';

/// Root widget: router, themes (vertical accent of the active business), uz locale, 24 h time.
class TizbizApp extends ConsumerWidget {
  const TizbizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(activeBusinessProvider.select((a) => a?.vertical.accent));
    return MaterialApp.router(
      title: 'TizBiz Biznes',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
