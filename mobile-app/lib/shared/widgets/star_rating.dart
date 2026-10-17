import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// 5 stars with halves, amber #F59E0B.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.size = 16});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.of(context).border;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 5.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            v >= i ? Icons.star_rounded : (v >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: v >= i - 0.5 ? AppColors.star : muted,
          ),
      ],
    );
  }
}
