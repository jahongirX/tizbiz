import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';

/// Refetch failed but old data is shown: "Ma'lumot yangilanmadi: `message`" + "Qayta urinish".
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Color.alphaBlend(c.warning.withValues(alpha: 0.15), c.surface),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.sync_problem, size: 18, color: c.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Ma'lumot yangilanmadi: ${errorText(error)}",
                style: TextStyle(color: c.text, fontSize: 13),
              ),
            ),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
          ],
        ),
      ),
    );
  }
}
