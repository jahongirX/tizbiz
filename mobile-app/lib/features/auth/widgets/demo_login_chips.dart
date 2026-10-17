import 'package:material_ui/material_ui.dart';

/// One demo account of the local / staging seed (BP §6.3).
typedef DemoLogin = ({String label, String phone});

const String kDemoPassword = 'secret123';

const List<DemoLogin> kDemoLogins = [
  (label: 'Barber egasi', phone: '+998901111111'),
  (label: 'Tort egasi', phone: '+998902222222'),
  (label: 'Klinika egasi', phone: '+998903333333'),
  (label: "To'yxona egasi", phone: '+998904444444'),
  (label: 'Usta (xodim)', phone: '+998931110001'),
  (label: 'Restoran egasi', phone: '+998905555555'),
  (label: 'Oshpaz (xodim)', phone: '+998932220001'),
  (label: 'Shifokor (xodim)', phone: '+998933330001'),
];

/// Quick-fill chips for the demo accounts (shown only with DEMO_LOGINS or in debug builds).
class DemoLoginChips extends StatelessWidget {
  const DemoLoginChips({super.key, required this.onPick, this.enabled = true});

  /// Called with the normalized phone and [kDemoPassword].
  final void Function(String phone, String password) onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo kirish', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in kDemoLogins)
                ActionChip(
                  label: Text(d.label),
                  onPressed: enabled ? () => onPick(d.phone, kDemoPassword) : null,
                ),
            ],
          ),
        ],
      );
}
