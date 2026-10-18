import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// The Bizcat Material 3 themes (BIZCAT-SPEC §3.2).
///
/// Fonts come only from the `TextStyle` helpers of google_fonts (`GoogleFonts.sora(...)`,
/// `GoogleFonts.manrope(...)`); its `TextTheme` helpers return SDK-material types and are never
/// used.
abstract final class AppTheme {
  /// [googleFonts] false in tests (no runtime font fetching): falls back to the default family.
  static ThemeData light({bool googleFonts = true}) => _build(
    brightness: Brightness.light,
    googleFonts: googleFonts,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: BzColors.indigo,
      onPrimary: BzColors.white,
      primaryContainer: BzColors.indigo50,
      onPrimaryContainer: BzColors.indigo,
      secondary: BzColors.apricot,
      onSecondary: BzColors.indigo,
      secondaryContainer: BzColors.indigo50,
      onSecondaryContainer: BzColors.indigo,
      tertiary: BzColors.indigo700,
      onTertiary: BzColors.white,
      error: BzColors.danger,
      onError: BzColors.white,
      errorContainer: BzColors.dangerBg,
      onErrorContainer: BzColors.danger,
      surface: BzColors.white,
      onSurface: BzColors.indigo,
      onSurfaceVariant: BzColors.muted,
      surfaceContainerLowest: BzColors.white,
      surfaceContainerLow: BzColors.white,
      surfaceContainer: BzColors.white,
      surfaceContainerHigh: BzColors.white,
      surfaceContainerHighest: BzColors.tile,
      outline: BzColors.border,
      outlineVariant: BzColors.border,
      inverseSurface: BzColors.indigo,
      onInverseSurface: BzColors.white,
      inversePrimary: BzColors.darkPrimary,
      surfaceTint: Colors.transparent,
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
    ),
    scaffold: BzColors.bg,
    text: BzColors.indigo,
    muted: BzColors.muted,
    border: BzColors.border,
    surface: BzColors.white,
    primary: BzColors.indigo,
    onPrimary: BzColors.white,
    indicator: BzColors.indigo50,
  );

  /// Dark variant (derived from indigo; the brand defines none).
  static ThemeData dark({bool googleFonts = true}) => _build(
    brightness: Brightness.dark,
    googleFonts: googleFonts,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: BzColors.darkPrimary,
      onPrimary: BzColors.indigo,
      primaryContainer: BzColors.indigo700,
      onPrimaryContainer: BzColors.darkText,
      secondary: BzColors.apricot,
      onSecondary: BzColors.indigo,
      secondaryContainer: BzColors.indigo700,
      onSecondaryContainer: BzColors.darkText,
      tertiary: BzColors.darkPrimary,
      onTertiary: BzColors.indigo,
      error: Color(0xFFF87171),
      onError: BzColors.indigo,
      errorContainer: Color(0xFF4C1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: BzColors.darkSurface,
      onSurface: BzColors.darkText,
      onSurfaceVariant: BzColors.darkMuted,
      surfaceContainerLowest: BzColors.darkBg,
      surfaceContainerLow: BzColors.darkSurface,
      surfaceContainer: BzColors.darkSurface,
      surfaceContainerHigh: BzColors.darkSurface,
      surfaceContainerHighest: BzColors.darkBorder,
      outline: BzColors.darkBorder,
      outlineVariant: BzColors.darkBorder,
      inverseSurface: BzColors.darkText,
      onInverseSurface: BzColors.indigo,
      inversePrimary: BzColors.indigo,
      surfaceTint: Colors.transparent,
      shadow: Color(0x66000000),
      scrim: Color(0x99000000),
    ),
    scaffold: BzColors.darkBg,
    text: BzColors.darkText,
    muted: BzColors.darkMuted,
    border: BzColors.darkBorder,
    surface: BzColors.darkSurface,
    primary: BzColors.darkPrimary,
    onPrimary: BzColors.indigo,
    indicator: BzColors.indigo700,
  );

  static ThemeData _build({
    required Brightness brightness,
    required bool googleFonts,
    required ColorScheme scheme,
    required Color scaffold,
    required Color text,
    required Color muted,
    required Color border,
    required Color surface,
    required Color primary,
    required Color onPrimary,
    required Color indicator,
  }) {
    TextStyle sora(double size, FontWeight w, [Color? color]) => googleFonts
        ? GoogleFonts.sora(fontSize: size, fontWeight: w, color: color ?? text)
        : TextStyle(fontSize: size, fontWeight: w, color: color ?? text);
    TextStyle manrope(double size, FontWeight w, [Color? color]) => googleFonts
        ? GoogleFonts.manrope(fontSize: size, fontWeight: w, color: color ?? text)
        : TextStyle(fontSize: size, fontWeight: w, color: color ?? text);

    final textTheme = TextTheme(
      displayLarge: sora(40, FontWeight.w700),
      displayMedium: sora(34, FontWeight.w700),
      displaySmall: sora(28, FontWeight.w700),
      headlineLarge: sora(30, FontWeight.w700),
      headlineMedium: sora(26, FontWeight.w700),
      headlineSmall: sora(22, FontWeight.w700),
      titleLarge: sora(19, FontWeight.w600),
      titleMedium: manrope(17, FontWeight.w700),
      titleSmall: manrope(15, FontWeight.w700),
      bodyLarge: manrope(17, FontWeight.w500),
      bodyMedium: manrope(15, FontWeight.w500),
      bodySmall: manrope(14, FontWeight.w500, muted),
      labelLarge: manrope(15, FontWeight.w700),
      labelMedium: manrope(13, FontWeight.w700),
      labelSmall: manrope(12, FontWeight.w700),
    );

    final radiusM = BorderRadius.circular(BzRadius.l);
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: text),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: text),
        actionsIconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BzRadius.xl)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onPrimary,
              disabledBackgroundColor: border,
              disabledForegroundColor: muted,
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: radiusM),
              textStyle: textTheme.labelLarge,
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.xl),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (s) =>
                    s.contains(WidgetState.pressed) ? BzColors.indigo700.withValues(alpha: isLight ? 0.6 : 0.2) : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: primary,
              disabledForegroundColor: muted,
              minimumSize: const Size(64, 52),
              side: BorderSide(color: primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: radiusM),
              textStyle: textTheme.labelLarge,
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.xl),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (s) => BorderSide(color: s.contains(WidgetState.disabled) ? border : primary, width: 1.2),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: muted,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radiusM),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: text, minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        helperMaxLines: 2,
        errorMaxLines: 3,
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        helperStyle: textTheme.bodySmall,
        errorStyle: manrope(13, FontWeight.w500, scheme.error),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : surface),
        selectedColor: primary,
        backgroundColor: surface,
        disabledColor: border,
        side: WidgetStateBorderSide.resolveWith(
          (s) => s.contains(WidgetState.selected) ? BorderSide(color: primary) : BorderSide(color: border),
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
        checkmarkColor: onPrimary,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? onPrimary : primary),
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: onPrimary),
        iconTheme: IconThemeData(color: primary, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.s, vertical: BzSpace.xs),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: indicator,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(color: s.contains(WidgetState.selected) ? primary : muted),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BzRadius.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BzRadius.xl)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BzColors.indigo,
        contentTextStyle: manrope(15, FontWeight.w500, BzColors.white),
        actionTextColor: BzColors.white,
        shape: RoundedRectangleBorder(borderRadius: radiusM),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: text,
        textColor: text,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        indicatorColor: primary,
        dividerColor: border,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : muted),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
        checkColor: WidgetStatePropertyAll(onPrimary),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : border),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onPrimary : surface),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusM),
        textStyle: textTheme.bodyMedium,
      ),
    );
  }
}

/// Font helpers that follow the active theme (they work with and without google_fonts).
///
/// Use these instead of calling `GoogleFonts.*` in widgets: `BzText.sora(context, 24)`.
abstract final class BzText {
  /// A Sora style (display/headline family of the theme) of [size]/[weight].
  static TextStyle sora(BuildContext context, double size, {FontWeight weight = FontWeight.w700, Color? color}) {
    final base = Theme.of(context).textTheme.displaySmall ?? const TextStyle();
    return base.copyWith(fontSize: size, fontWeight: weight, color: color, height: 1.25);
  }

  /// A Manrope style (body family of the theme) of [size]/[weight].
  static TextStyle manrope(BuildContext context, double size, {FontWeight weight = FontWeight.w500, Color? color}) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(fontSize: size, fontWeight: weight, color: color);
  }
}
