import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';

/// The staff member's login is not linked to a staff profile (no `active.staff_id`).
class StaffNotLinkedView extends ConsumerWidget {
  const StaffNotLinkedView({super.key, this.compact = false});

  /// Card-sized variant (profile screen).
  final bool compact;

  static const title = "Hisobingiz xodimga bog'lanmagan";
  static const message =
      "Biznes egasidan Jamoa bo'limida hisobingizni xodim profiliga bog'lashni so'rang.";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = OutlinedButton.icon(
      onPressed: () => ref.read(sessionProvider.notifier).refreshMe(),
      icon: const Icon(Icons.refresh),
      label: const Text('Qayta tekshirish'),
    );
    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              const Text(message),
              const SizedBox(height: 12),
              button,
            ],
          ),
        ),
      );
    }
    return EmptyView(icon: Icons.link_off, title: title, message: message, action: button);
  }
}
