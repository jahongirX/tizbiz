import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';

/// Shown in both shells while the session was booted from the cached `/auth/me`.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    return Material(
      color: Color.alphaBlend(c.warning.withValues(alpha: 0.18), c.surface),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 18, color: c.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Oflayn rejim. Ma'lumotlar eskirgan bo'lishi mumkin.",
                  style: TextStyle(color: c.text, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(sessionProvider.notifier).refreshMe(),
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
