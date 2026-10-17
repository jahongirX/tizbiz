import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// Form-level error above the submit button; renders nothing when [message] is null/empty.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final m = message?.trim();
    if (m == null || m.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(m, style: TextStyle(color: c.danger, fontSize: 13))),
        ],
      ),
    );
  }
}
