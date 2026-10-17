import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Business vertical: accent colour, icon and label (apps/admin/src/lib/verticals.js).
enum Vertical {
  barber('barber', 'Barber', Color(0xFF3B82F6), Icons.content_cut),
  cafe('cafe', 'Kafe / Tort', Color(0xFFF97316), Icons.restaurant),
  clinic('clinic', 'Klinika', Color(0xFF10B981), Icons.medical_services_outlined),
  rental('rental', 'Ijara', Color(0xFF8B5CF6), Icons.celebration_outlined);

  const Vertical(this.key, this.label, this.accent, this.icon);

  final String key;
  final String label;
  final Color accent;
  final IconData icon;

  static const Map<String, Vertical> _aliases = {
    'salon': barber,
    'dentistry': clinic,
    'diagnostics': clinic,
    'restaurant': cafe,
  };

  /// category -> key; aliases salon->barber, dentistry|diagnostics->clinic, restaurant->cafe;
  /// else by engine (slot->barber, catalog->cafe, medical->clinic, rental->rental); else barber.
  static Vertical of({String? category, Engine? engine}) {
    final c = category?.trim().toLowerCase();
    if (c != null && c.isNotEmpty) {
      for (final v in values) {
        if (v.key == c) return v;
      }
      final alias = _aliases[c];
      if (alias != null) return alias;
    }
    return switch (engine) {
      Engine.catalog => cafe,
      Engine.medical => clinic,
      Engine.rental => rental,
      Engine.slot || null => barber,
    };
  }
}
