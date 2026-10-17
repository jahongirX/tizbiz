import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/settings/widgets/section_form.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

String _fmtCoord(double? v) => v == null ? '' : v.toString();

String? Function(String?) _coord(double min, double max) => (v) {
      final t = (v ?? '').trim();
      if (t.isEmpty) return null;
      final n = parseDecimal(t);
      if (n == null) return "Son noto'g'ri";
      if (n < min || n > max) return '${min.toInt()} dan ${max.toInt()} gacha';
      return null;
    };

/// 3. "Manzil va katalog": address, city, district, map_url, lat, lng, is_listed.
class LocationSection extends SettingsSectionWidget {
  const LocationSection({super.key, required super.settings, super.onDirty});

  @override
  SettingsSectionState<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends SettingsSectionState<LocationSection> {
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _mapUrl;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late bool _listed;

  @override
  Set<String> get keys => const {'address', 'city', 'district', 'map_url', 'lat', 'lng', 'is_listed'};

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _address = TextEditingController(text: s.address ?? '')..addListener(changed);
    _city = TextEditingController(text: s.city ?? '')..addListener(changed);
    _district = TextEditingController(text: s.district ?? '')..addListener(changed);
    _mapUrl = TextEditingController(text: s.mapUrl ?? '')..addListener(changed);
    _lat = TextEditingController(text: _fmtCoord(s.lat))..addListener(changed);
    _lng = TextEditingController(text: _fmtCoord(s.lng))..addListener(changed);
    _listed = s.isListed;
    markClean();
  }

  @override
  void dispose() {
    for (final c in [_address, _city, _district, _mapUrl, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  List<Object?> snapshot() => [
        _address.text.trim(), _city.text.trim(), _district.text.trim(), _mapUrl.text.trim(), //
        _lat.text.trim(), _lng.text.trim(), _listed,
      ];

  @override
  BookingSettings buildEdited(BookingSettings base) => base.copyWith(
        address: textOrNull(_address),
        city: textOrNull(_city),
        district: textOrNull(_district),
        mapUrl: textOrNull(_mapUrl),
        lat: parseDecimal(_lat.text),
        lng: parseDecimal(_lng.text),
        isListed: _listed,
      );

  Widget _text(TextEditingController c, String label, String key, {String? Function(String?)? validator, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          enabled: !saving,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, errorText: fieldErrors[key]),
          validator: validator,
        ),
      );

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true, signed: true);
    return section(title: 'Manzil va katalog', children: [
      _text(_address, 'Manzil', 'address'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _text(_city, 'Shahar', 'city')),
          const SizedBox(width: 12),
          Expanded(child: _text(_district, 'Tuman', 'district')),
        ],
      ),
      _text(_mapUrl, 'Xarita havolasi', 'map_url', type: TextInputType.url, validator: (v) {
        final t = (v ?? '').trim();
        return t.isEmpty || t.startsWith('http') ? null : "Havola http bilan boshlanishi kerak";
      }),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _text(_lat, 'Kenglik', 'lat', type: decimal, validator: _coord(-90, 90))),
          const SizedBox(width: 12),
          Expanded(child: _text(_lng, 'Uzunlik', 'lng', type: decimal, validator: _coord(-180, 180))),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("Bizcat katalogida ko'rsatish"),
        value: _listed,
        onChanged: saving
            ? null
            : (v) {
                _listed = v;
                changed();
              },
      ),
    ]);
  }
}
