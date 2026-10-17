import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Marker size; the tail tip sits on the business's coordinate.
const Size kMapPinSize = Size(56, 66);

/// A round logo bubble with a tail. The selected pin is full size with an apricot ring
/// (brand: apricot is for CTAs and map pins), the others are smaller with a white ring.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.card, required this.selected});

  final BusinessCard card;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ring = selected ? BzColors.apricot : BzColors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: card.name,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1 : 0.78,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ring,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: BzColors.indigo.withValues(alpha: selected ? 0.35 : 0.22),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: BizLogo(url: card.logo, name: card.name, size: 50, brandColor: card.brandColor),
              ),
            ),
            CustomPaint(size: const Size(14, 10), painter: _TailPainter(ring)),
          ],
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// The consumer's own position: a blue dot with a soft halo.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  static const color = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mening joylashuvim',
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: BzColors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}
