import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One service / menu item / rental item row.
class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.service, required this.engine, this.onTap});

  final Service service;
  final Engine engine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = service;
    final muted = !s.isActive;
    final meta = [
      if (engine != Engine.catalog) UzDates.duration(s.durationMin),
      Money.format(s.priceTiyin),
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: _Thumb(url: s.image, muted: muted),
      title: Text(s.name, style: muted ? TextStyle(color: c.textMuted) : null),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta, style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (s.requiresDeposit) _Chip(text: 'Depozit ${Money.compact(s.depositTiyin!)}', fg: c.warning),
              if (engine != Engine.catalog)
                s.onlineBookable ? _Chip(text: 'Onlayn', fg: c.success) : _Chip(text: 'Faqat admin', fg: c.textMuted),
              if (muted) _Chip(text: 'Nofaol', fg: c.textMuted),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.muted});

  final String? url;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fallback = Container(
      width: 48,
      height: 48,
      color: c.surface2,
      child: Icon(Icons.design_services_outlined, color: c.textMuted, size: 22),
    );
    final img = url == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: url!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Opacity(opacity: muted ? 0.5 : 1, child: img),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.fg});

  final String text;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
