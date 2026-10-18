import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/features/onboarding/widgets/city_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Choose the city the home and the directory filter by (BIZCAT-SPEC §9.1).
class CityPickerScreen extends ConsumerWidget {
  const CityPickerScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, String? city) async {
    final router = GoRouter.of(context);
    unawaited(ref.read(cityProvider.notifier).set(city));
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(cityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Shahar')),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            for (final c in kCityOptions)
              CityOptionTile(city: c, selected: c == current, onTap: () => unawaited(_pick(context, ref, c))),
          ],
        ),
      ),
    );
  }
}
