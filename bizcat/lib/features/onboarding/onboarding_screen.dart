import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/features/onboarding/widgets/city_options.dart';
import 'package:bizcat/shared/widgets/brand.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/theme/app_theme.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// First-run intro: two info pages and the city choice (BIZCAT-SPEC §9.1).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = 3;
  final _controller = PageController();
  int _page = 0;
  late String? _city = ref.read(cityProvider);
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _target => safeFrom(widget.from) ?? AppRoutes.home;

  void _skipToCity() => unawaited(
        _controller.animateToPage(_pages - 1, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      );

  Future<void> _finish({required bool withCity}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final router = GoRouter.of(context);
    if (withCity) await ref.read(cityProvider.notifier).set(_city);
    await ref.read(appPrefsProvider).setOnboarded(true);
    router.go(_target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: _page < _pages - 1
                    ? Padding(
                        padding: const EdgeInsets.only(right: BzSpace.s),
                        child: TextButton(onPressed: _skipToCity, child: const Text("O'tkazib yuborish")),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _InfoPage(
                    visual: BrandMark(size: 96),
                    title: 'Shahringizdagi eng yaxshi joylar',
                    text: "Sartaroshxona, klinika, kafe va to'yxonalar bir ilovada.",
                  ),
                  _InfoPage(
                    visual: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.event_available, size: 72, color: scheme.primary),
                    ),
                    title: 'Navbat bir necha bosishda',
                    text: "Qo'ng'iroqsiz yoziling, bronlaringiz doim qo'lingizda.",
                  ),
                  _CityPage(
                    selected: _city,
                    onSelect: (c) => setState(() => _city = c),
                  ),
                ],
              ),
            ),
            _Dots(count: _pages, index: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.l),
              child: _page < _pages - 1
                  ? SecondaryButton(
                      label: 'Davom etish',
                      onPressed: () => unawaited(_controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      )),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CtaButton(
                          label: 'Boshlash',
                          loading: _finishing,
                          onPressed: () => unawaited(_finish(withCity: true)),
                        ),
                        const SizedBox(height: BzSpace.xs),
                        TextButton(
                          onPressed: _finishing ? null : () => unawaited(_finish(withCity: false)),
                          child: const Text('Keyinroq'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.visual, required this.title, required this.text});

  final Widget visual;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: BzSpace.xxl, vertical: BzSpace.xxxl),
      child: Column(
        children: [
          const SizedBox(height: BzSpace.xxxl),
          visual,
          const SizedBox(height: BzSpace.xxxl),
          Text(title, textAlign: TextAlign.center, style: BzText.sora(context, 24, weight: FontWeight.w700)),
          const SizedBox(height: BzSpace.m),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CityPage extends StatelessWidget {
  const _CityPage({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: BzSpace.xl),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BzSpace.xxl),
          child: Column(
            children: [
              Text(
                'Shahringizni tanlang',
                textAlign: TextAlign.center,
                style: BzText.sora(context, 24, weight: FontWeight.w700),
              ),
              const SizedBox(height: BzSpace.m),
              Text(
                "Keyin profilda o'zgartirishingiz mumkin.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: BzSpace.xl),
        for (final c in kCityOptions)
          CityOptionTile(city: c, radio: true, selected: c == selected, onTap: () => onSelect(c)),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(BzRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}
