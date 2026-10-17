import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// "Label ........ value" row for detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: TextStyle(color: AppColors.of(context).textMuted, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
          ],
        ),
      );
}
