import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';

/// Unknown location or unparseable path/query parameter.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.explore_off_outlined,
        title: 'Sahifa topilmadi',
        action: FilledButton(
          onPressed: () => context.go(active == null ? Routes.splash : Routes.homeFor(active)),
          child: const Text('Bosh sahifa'),
        ),
      ),
    );
  }
}
