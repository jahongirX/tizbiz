import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/settings/widgets/section_form.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

final RegExp kSlugPattern = RegExp(r'^[a-z0-9-]{3,80}$');
const kSlugInvalid = "Slug 3–80 belgi: kichik lotin harflari, raqamlar va '-'";

/// Client-side slug check (server 422 pointer `slug` is shown as is).
String? validateSlug(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Slugni kiriting';
  return kSlugPattern.hasMatch(s) ? null : kSlugInvalid;
}

/// Int in [min]..[max], required.
String? Function(String?) intRange(int min, int max) => (v) {
      final n = int.tryParse((v ?? '').trim());
      if (n == null) return 'Sonni kiriting';
      if (n < min || n > max) return '$min dan $max gacha';
      return null;
    };

/// 1. "Onlayn yozuv": online_booking_enabled, booking_lead_min, booking_horizon_days, slug.
class BookingSection extends SettingsSectionWidget {
  const BookingSection({super.key, required super.settings, super.onDirty});

  @override
  SettingsSectionState<BookingSection> createState() => _BookingSectionState();
}

class _BookingSectionState extends SettingsSectionState<BookingSection> {
  late bool _enabled;
  late final TextEditingController _lead;
  late final TextEditingController _horizon;
  late final TextEditingController _slug;

  @override
  Set<String> get keys => const {'online_booking_enabled', 'booking_lead_min', 'booking_horizon_days', 'slug'};

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _enabled = s.onlineBookingEnabled;
    _lead = TextEditingController(text: '${s.bookingLeadMin}')..addListener(changed);
    _horizon = TextEditingController(text: '${s.bookingHorizonDays}')..addListener(changed);
    _slug = TextEditingController(text: s.slug)..addListener(changed);
    markClean();
  }

  @override
  void dispose() {
    _lead.dispose();
    _horizon.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  List<Object?> snapshot() => [_enabled, _lead.text.trim(), _horizon.text.trim(), _slug.text.trim()];

  @override
  BookingSettings buildEdited(BookingSettings base) => base.copyWith(
        onlineBookingEnabled: _enabled,
        bookingLeadMin: int.parse(_lead.text.trim()),
        bookingHorizonDays: int.parse(_horizon.text.trim()),
        slug: _slug.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final slug = _slug.text.trim();
    final slugChanged = slug != widget.settings.slug;
    return section(title: 'Onlayn yozuv', children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Onlayn yozilish yoqilgan'),
        value: _enabled,
        onChanged: saving
            ? null
            : (v) {
                _enabled = v;
                changed();
              },
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _lead,
        enabled: !saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Eng kamida necha daqiqa oldin',
          suffixText: 'daqiqa',
          errorText: fieldErrors['booking_lead_min'],
        ),
        validator: intRange(0, 10080),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _horizon,
        enabled: !saving,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Necha kun oldinga',
          suffixText: 'kun',
          errorText: fieldErrors['booking_horizon_days'],
        ),
        validator: intRange(1, 365),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _slug,
        enabled: !saving,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Slug',
          helperText: 'https://${slug.isEmpty ? '...' : slug}.tizbiz.uz',
          errorText: fieldErrors['slug'],
          errorMaxLines: 3,
        ),
        validator: validateSlug,
      ),
      if (slugChanged) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: c.warning),
            const SizedBox(width: 6),
            const Expanded(child: Text("Slugni o'zgartirsangiz eski havolalar ishlamay qoladi")),
          ],
        ),
      ],
    ]);
  }
}
