import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/app/theme/app_theme.dart';
import 'package:tizbiz_biznes/app/theme/vertical.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('light theme with an accent', () {
    final t = AppTheme.light(Vertical.cafe.accent);
    expect(t.useMaterial3, isTrue);
    expect(t.brightness, Brightness.light);
    expect(t.colorScheme.primary, Vertical.cafe.accent);
    expect(t.scaffoldBackgroundColor, const Color(0xFFF5F6F8));
    final c = t.extension<AppColors>();
    expect(c, isNotNull);
    expect(c!.primary, Vertical.cafe.accent);
    expect(c.surface, const Color(0xFFFFFFFF));
  });

  test('dark theme defaults to the dark primary', () {
    final t = AppTheme.dark();
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, AppColors.defaultPrimaryDark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF0F1115));
    expect(t.extension<AppColors>()!.bg, const Color(0xFF0F1115));
    expect(t.colorScheme.error, const Color(0xFFEF4444));
  });

  test('status colours', () {
    expect(AppColors.light.appointmentStatus(AppointmentStatus.pending).bg, const Color(0xFFFEF3C7));
    expect(AppColors.dark.appointmentStatus(AppointmentStatus.noShow).fg, const Color(0xFFFCA5A5));
    expect(AppColors.light.orderStatusColor(OrderStatus.preparing), const Color(0xFFF59E0B));
  });

  test('Vertical.of: category, aliases, engine fallback', () {
    expect(Vertical.of(category: 'barber'), Vertical.barber);
    expect(Vertical.of(category: 'salon'), Vertical.barber);
    expect(Vertical.of(category: 'dentistry'), Vertical.clinic);
    expect(Vertical.of(category: 'diagnostics'), Vertical.clinic);
    expect(Vertical.of(category: 'restaurant'), Vertical.cafe);
    expect(Vertical.of(category: 'unknown', engine: Engine.rental), Vertical.rental);
    expect(Vertical.of(engine: Engine.catalog), Vertical.cafe);
    expect(Vertical.of(engine: Engine.medical), Vertical.clinic);
    expect(Vertical.of(), Vertical.barber);
  });

  testWidgets('themes build in a MaterialApp', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(Vertical.clinic.accent),
        darkTheme: AppTheme.dark(Vertical.clinic.accent),
        themeMode: mode,
        home: Builder(builder: (context) => Text(AppColors.of(context).primary.toString())),
      ));
      expect(find.text(Vertical.clinic.accent.toString()), findsOneWidget);
    }
  });
}
