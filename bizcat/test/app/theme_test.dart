import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Color? _materialColor(WidgetTester t, Finder button) =>
    t.widget<Material>(find.descendant(of: button, matching: find.byType(Material)).first).color;

Color? _textColor(WidgetTester t, String text) => t.renderObject<RenderParagraph>(find.text(text)).text.style?.color;

Future<void> _pump(WidgetTester t, Widget child, {ThemeData? theme}) => t.pumpWidget(MaterialApp(
      theme: theme ?? AppTheme.light(googleFonts: false),
      home: Scaffold(body: Center(child: child)),
    ));

void main() {
  test('light scheme: indigo primary, apricot secondary, cool lavender scaffold', () {
    final theme = AppTheme.light(googleFonts: false);
    expect(theme.colorScheme.primary, BzColors.indigo);
    expect(theme.colorScheme.onPrimary, BzColors.white);
    expect(theme.colorScheme.secondary, BzColors.apricot);
    expect(theme.colorScheme.onSecondary, BzColors.indigo);
    expect(theme.colorScheme.surface, BzColors.white);
    expect(theme.colorScheme.onSurface, BzColors.indigo);
    expect(theme.colorScheme.error, BzColors.danger);
    expect(theme.scaffoldBackgroundColor, BzColors.bg);
    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.displaySmall?.fontSize, 28);
    expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w700);
    expect(theme.navigationBarTheme.height, 68);
  });

  test('dark scheme', () {
    final theme = AppTheme.dark(googleFonts: false);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, BzColors.darkPrimary);
    expect(theme.colorScheme.onPrimary, BzColors.indigo);
    expect(theme.colorScheme.surface, BzColors.darkSurface);
    expect(theme.scaffoldBackgroundColor, BzColors.darkBg);
  });

  testWidgets('the default FilledButton is indigo (not apricot)', (t) async {
    await _pump(t, FilledButton(onPressed: () {}, child: const Text('Kirish')));
    expect(_materialColor(t, find.byType(FilledButton)), BzColors.indigo);
    expect(_textColor(t, 'Kirish'), BzColors.white);
  });

  testWidgets('PrimaryButton is indigo, SecondaryButton is outlined indigo', (t) async {
    await _pump(
      t,
      Column(children: [
        PrimaryButton(label: 'Saqlash', onPressed: () {}),
        SecondaryButton(label: 'Orqaga', onPressed: () {}),
      ]),
    );
    expect(_materialColor(t, find.byType(PrimaryButton)), BzColors.indigo);
    expect(_textColor(t, 'Orqaga'), BzColors.indigo);
  });

  testWidgets('CtaButton: apricot background, indigo label', (t) async {
    await _pump(t, CtaButton(label: 'Band qilish', onPressed: () {}));
    expect(_materialColor(t, find.byType(CtaButton)), BzColors.apricot);
    expect(_textColor(t, 'Band qilish'), BzColors.indigo);
  });

  testWidgets('CtaButton stays apricot with indigo text in dark mode', (t) async {
    await _pump(t, CtaButton(label: 'Band qilish', onPressed: () {}), theme: AppTheme.dark(googleFonts: false));
    expect(_materialColor(t, find.byType(CtaButton)), BzColors.apricot);
    expect(_textColor(t, 'Band qilish'), BzColors.indigo);
  });

  testWidgets('CtaButton disabled: border-color background, muted text', (t) async {
    await _pump(t, const CtaButton(label: 'Kod olish'));
    expect(_materialColor(t, find.byType(CtaButton)), BzColors.border);
    expect(_textColor(t, 'Kod olish'), BzColors.muted);
  });

  testWidgets('CtaButton loading: spinner and taps ignored', (t) async {
    var taps = 0;
    await _pump(t, CtaButton(label: 'Tasdiqlash', loading: true, onPressed: () => taps++));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tasdiqlash'), findsNothing);
    await t.tap(find.byType(CtaButton), warnIfMissed: false);
    expect(taps, 0);
    expect(_materialColor(t, find.byType(CtaButton)), BzColors.apricot);
  });
}
