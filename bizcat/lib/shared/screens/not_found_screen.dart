import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Unknown route or a bad id.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.search_off,
        title: 'Sahifa topilmadi',
        actionLabel: 'Bosh sahifaga',
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
