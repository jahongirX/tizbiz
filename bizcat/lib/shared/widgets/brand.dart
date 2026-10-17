import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

enum BrandLogoVariant { onLight, onDark }

/// The Bizcat wordmark. Width never below 120 (brand minimum). Never recolor or stretch it.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.variant = BrandLogoVariant.onLight, this.width = 132});

  final BrandLogoVariant variant;
  final double width;

  static const String onLightAsset = 'assets/brand/bizcat-logo-on-light.svg';
  static const String onDarkAsset = 'assets/brand/bizcat-logo-on-dark.svg';

  @override
  Widget build(BuildContext context) {
    final w = width < 120 ? 120.0 : width;
    return Semantics(
      label: 'Bizcat',
      image: true,
      child: SvgPicture.asset(
        variant == BrandLogoVariant.onDark ? onDarkAsset : onLightAsset,
        width: w,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// The Bizcat mark (cat head + map pin). Minimum 24; below 32 px the simplified favicon is used.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  static const String markAsset = 'assets/brand/bizcat-mark.svg';
  static const String faviconAsset = 'assets/brand/bizcat-favicon.svg';

  @override
  Widget build(BuildContext context) {
    final s = size < 24 ? 24.0 : size;
    return Semantics(
      label: 'Bizcat',
      image: true,
      child: SvgPicture.asset(s < 32 ? faviconAsset : markAsset, width: s, height: s, fit: BoxFit.contain),
    );
  }
}
