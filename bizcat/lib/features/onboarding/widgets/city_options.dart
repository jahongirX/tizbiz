import 'package:bizcat/core/city.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:material_ui/material_ui.dart';

/// The city choices in display order: null (`Barcha shaharlar`) first, then [kCities].
const List<String?> kCityOptions = [null, ...kCities];

/// One selectable city row. [radio] shows a radio mark on the left (onboarding); otherwise the
/// selected row gets an indigo check on the right (city picker).
class CityOptionTile extends StatelessWidget {
  const CityOptionTile({
    super.key,
    required this.city,
    required this.selected,
    required this.onTap,
    this.radio = false,
  });

  final String? city;
  final bool selected;
  final VoidCallback onTap;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = cityLabel(city);
    return Semantics(
      selected: selected,
      button: true,
      child: ListTile(
        key: ValueKey('city-${city ?? 'all'}'),
        onTap: onTap,
        leading: radio
            ? Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              )
            : Icon(city == null ? BzIcons.globe : BzIcons.location, color: scheme.onSurfaceVariant),
        title: Text(label, style: selected ? const TextStyle(fontWeight: FontWeight.w600) : null),
        trailing: !radio && selected ? Icon(BzIcons.check, color: scheme.primary) : null,
      ),
    );
  }
}
