import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';

/// One demo account of the demo seed (docs/mobile/README.md): a business and who signs in.
typedef DemoLogin = ({String label, String business, String phone, IconData icon, bool staff});

const String kDemoPassword = 'secret123';

const List<DemoLogin> kDemoLogins = [
  (label: 'Sartaroshxona', business: 'Shox Barber', phone: '+998901111111', icon: Icons.content_cut, staff: false),
  (label: 'Tort do\'koni', business: 'Aziza Tortlari', phone: '+998902222222', icon: Icons.cake_outlined, staff: false),
  (
    label: 'Klinika',
    business: 'Sanatrix Klinikasi',
    phone: '+998903333333',
    icon: Icons.local_hospital_outlined,
    staff: false,
  ),
  (
    label: "To'yxona",
    business: "Serenada To'yxona",
    phone: '+998904444444',
    icon: Icons.celebration_outlined,
    staff: false,
  ),
  (label: 'Restoran', business: 'Milliy Taomlar', phone: '+998905555555', icon: Icons.restaurant, staff: false),
  (
    label: 'Usta (xodim)',
    business: 'Bekzod usta · Shox Barber',
    phone: '+998931110001',
    icon: Icons.content_cut,
    staff: true,
  ),
  (
    label: 'Tortchi (xodim)',
    business: 'Aziza opa · Aziza Tortlari',
    phone: '+998932220001',
    icon: Icons.cake_outlined,
    staff: true,
  ),
  (
    label: 'Shifokor (xodim)',
    business: 'Dr. Kamola · Sanatrix',
    phone: '+998933330001',
    icon: Icons.local_hospital_outlined,
    staff: true,
  ),
  (
    label: "To'yxona (xodim)",
    business: 'Serenada zali',
    phone: '+998934440001',
    icon: Icons.celebration_outlined,
    staff: true,
  ),
];

/// One-tap demo sign-in: business owners and staff of the demo businesses, no typing
/// (shown with DEMO_LOGINS, which the CI APK build sets, or in debug builds).
class DemoLoginChips extends StatelessWidget {
  const DemoLoginChips({super.key, required this.onPick, this.enabled = true});

  /// Called with the normalized phone and [kDemoPassword].
  final void Function(String phone, String password) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    Widget group(String title, bool staff) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: c.textMuted)),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final d in kDemoLogins.where((d) => d.staff == staff))
                  SizedBox(
                    width: w,
                    child: _DemoCard(demo: d, enabled: enabled, onTap: () => onPick(d.phone, kDemoPassword)),
                  ),
              ],
            );
          },
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.primarySoft.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: c.primary),
              const SizedBox(width: 6),
              Expanded(child: Text('Demo sifatida kirish', style: theme.textTheme.titleMedium)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
            child: Text('Parolsiz, bir bosishda', style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted)),
          ),
          group('Biznes egasi', false),
          const SizedBox(height: 8),
          group('Xodim', true),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.demo, required this.enabled, required this.onTap});

  final DemoLogin demo;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('demo-${demo.phone}'),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: demo.staff ? c.surface2 : c.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(demo.icon, size: 20, color: c.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(demo.label, style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      demo.business,
                      style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
