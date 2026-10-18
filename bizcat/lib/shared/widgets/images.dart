import 'package:bizcat/core/images.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Parses '#RRGGBB' (or 'RRGGBB' / '#AARRGGBB'); null when invalid.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// A network image (cached) with an indigo50 placeholder; tests disable network images.
class NetImage extends ConsumerWidget {
  const NetImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius,
    this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? radius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ph =
        placeholder ?? Container(width: width, height: height, color: Theme.of(context).colorScheme.primaryContainer);
    final u = url?.trim();
    Widget child;
    if (u == null || u.isEmpty || !ref.watch(netImagesEnabledProvider)) {
      child = SizedBox(width: width, height: height, child: ph);
    } else {
      child = CachedNetworkImage(
        imageUrl: u,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, _) => ph,
        errorWidget: (_, _, _) => ph,
      );
    }
    return radius == null ? child : ClipRRect(borderRadius: radius!, child: child);
  }
}

/// Business logo: the image, or initials (first letters of the first 2 words) on brandColor.
class BizLogo extends StatelessWidget {
  const BizLogo({super.key, this.url, required this.name, this.size = 48, this.brandColor});

  final String? url;
  final String name;
  final double size;

  /// '#RRGGBB'; fallback indigo.
  final String? brandColor;

  /// 'Shox Barber' -> 'SB'; 'aziza' -> 'A'; '' -> '?'.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final s = words.map((w) => w.characters.first.toUpperCase()).join();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 4);
    final bg = parseHexColor(brandColor) ?? BzColors.indigo;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Text(
        initials(name),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: BzColors.white,
          height: 1,
        ),
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: (url == null || url!.trim().isEmpty)
          ? fallback
          : NetImage(url: url, width: size, height: size, radius: radius, placeholder: fallback),
    );
  }
}

/// Cover image with a dark gradient overlay (black 18% -> 55%); without a URL a gradient from
/// brandColor (or indigo) to indigo700.
class BizCover extends StatelessWidget {
  const BizCover({super.key, this.url, this.brandColor, this.aspectRatio = 16 / 9, this.child});

  final String? url;
  final String? brandColor;

  /// null = fill the parent (e.g. inside a SliverAppBar).
  final double? aspectRatio;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final base = parseHexColor(brandColor) ?? BzColors.indigo;
    final gradientBg = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, BzColors.indigo700],
        ),
      ),
    );
    final hasUrl = url != null && url!.trim().isNotEmpty;
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        if (hasUrl) NetImage(url: url, placeholder: gradientBg) else gradientBg,
        if (hasUrl)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x2E000000), Color(0x8C000000)],
              ),
            ),
          ),
        ?child,
      ],
    );
    return aspectRatio == null ? stack : AspectRatio(aspectRatio: aspectRatio!, child: stack);
  }
}
