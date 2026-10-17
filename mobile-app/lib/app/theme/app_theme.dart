import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// Material 3 themes that mirror the web cabinet. [accent] (the active business's vertical
/// accent) replaces the default primary, as the web shell does.
abstract final class AppTheme {
  static Color defaultPrimary(Brightness b) =>
      b == Brightness.dark ? AppColors.defaultPrimaryDark : AppColors.defaultPrimaryLight;

  static ThemeData light([Color? accent]) => _build(Brightness.light, AppColors.light.withPrimary(accent));

  static ThemeData dark([Color? accent]) => _build(Brightness.dark, AppColors.dark.withPrimary(accent));

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: Colors.white,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.text,
      secondary: c.primary,
      onSecondary: Colors.white,
      secondaryContainer: c.primarySoft,
      onSecondaryContainer: c.text,
      tertiary: c.warning,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface2,
      surfaceTint: Colors.transparent,
      outline: c.border,
      outlineVariant: c.border,
      shadow: Colors.black,
      inverseSurface: c.text,
      onInverseSurface: c.surface,
      inversePrimary: c.primarySoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.surface,
      dividerColor: c.border,
      extensions: [c],
    );

    final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);
    final textTheme = text.copyWith(
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: c.textMuted),
      titleLarge: text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );

    final radius8 = BorderRadius.circular(8);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: radius8, borderSide: BorderSide(color: color, width: width));

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17, color: c.text),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.primary, 1.5),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.5),
        hintStyle: TextStyle(color: c.textMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.primary : c.textMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? c.primary : c.textMuted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primarySoft,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: c.text, fontSize: 13),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: ListTileThemeData(iconColor: c.textMuted, textColor: c.text),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.primarySoft),
      tabBarTheme: TabBarThemeData(
        labelColor: c.primary,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.primary,
        dividerColor: c.border,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius8),
          minimumSize: const Size(64, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius8),
          side: BorderSide(color: c.border),
          minimumSize: const Size(64, 44),
        ),
      ),
    );
  }
}
