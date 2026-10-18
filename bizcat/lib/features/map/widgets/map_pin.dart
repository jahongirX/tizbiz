import 'package:bizcat/shared/widgets/images.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Marker size; the tail tip sits on the business's coordinate.
const Size kMapPinSize = Size(92, 80);

/// `4.6 (12)` / `Yangi` for a pin's rating label.
String pinRatingLabel(BusinessCard card) =>
    card.ratingCount > 0 ? '${card.ratingAvg.toStringAsFixed(1)} (${card.ratingCount})' : 'Yangi';

/// A placemark: the business logo in a round bubble, a white rating pill (`★ 4.6 (12)`)
/// overlapping its bottom, and a tail. The selected pin is larger with an apricot ring
/// (brand: apricot is for CTAs and map pins).
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.card, required this.selected});

  final BusinessCard card;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ring = selected ? BzColors.apricot : BzColors.white;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${card.name}, reyting ${pinRatingLabel(card)}',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? 1.12 : 0.92,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: kMapPinSize.width,
          height: kMapPinSize.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 68,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 54,
                      height: 54,
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
                        child: BizLogo(url: card.logo, name: card.name, size: 48, brandColor: card.brandColor),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: selected ? BzColors.indigo : BzColors.white,
                          borderRadius: BorderRadius.circular(BzRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: BzColors.indigo.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (card.ratingCount > 0) ...[
                              const Icon(Icons.star_rounded, size: 13, color: BzColors.apricot),
                              const SizedBox(width: 2),
                            ],
                            Text(
                              pinRatingLabel(card),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                height: 1.1,
                                color: selected ? BzColors.white : BzColors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(size: const Size(12, 8), painter: _TailPainter(selected ? BzColors.indigo : BzColors.white)),
            ],
          ),
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
