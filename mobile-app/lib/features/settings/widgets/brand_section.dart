import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/settings/widgets/section_form.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

final RegExp kHexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

const List<String> kBrandSwatches = [
  '#1E1B4B', '#2563EB', '#0EA5E9', '#10B981', '#F59E0B', '#F97316', '#EF4444', '#8B5CF6', //
];

/// '#RRGGBB' -> Color; null when invalid.
Color? hexToColor(String? hex) {
  final h = hex?.trim();
  if (h == null || !kHexColor.hasMatch(h)) return null;
  return Color(int.parse('FF${h.substring(1)}', radix: 16));
}

String? validateHex(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  return kHexColor.hasMatch(t) ? null : "Rang #RRGGBB ko'rinishida bo'lsin";
}

/// 4. "Brend": read-only logo/cover previews, brand_color, brand_color_2.
class BrandSection extends SettingsSectionWidget {
  const BrandSection({super.key, required super.settings, super.onDirty});

  @override
  SettingsSectionState<BrandSection> createState() => _BrandSectionState();
}

class _BrandSectionState extends SettingsSectionState<BrandSection> {
  late final TextEditingController _c1;
  late final TextEditingController _c2;

  @override
  Set<String> get keys => const {'brand_color', 'brand_color_2', 'logo', 'cover'};

  @override
  void initState() {
    super.initState();
    _c1 = TextEditingController(text: widget.settings.brandColor ?? '')..addListener(changed);
    _c2 = TextEditingController(text: widget.settings.brandColor2 ?? '')..addListener(changed);
    markClean();
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  @override
  List<Object?> snapshot() => [_c1.text.trim().toUpperCase(), _c2.text.trim().toUpperCase()];

  @override
  BookingSettings buildEdited(BookingSettings base) =>
      base.copyWith(brandColor: textOrNull(_c1), brandColor2: textOrNull(_c2));

  Widget _colorField(TextEditingController c, String label, String key) {
    final colors = AppColors.of(context);
    final current = c.text.trim().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c,
          enabled: !saving,
          decoration: InputDecoration(
            labelText: label,
            hintText: '#2563EB',
            errorText: fieldErrors[key],
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: hexToColor(c.text) ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.border),
                ),
              ),
            ),
          ),
          validator: validateHex,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in kBrandSwatches)
              Semantics(
                button: true,
                label: hex,
                child: InkWell(
                  onTap: saving ? null : () => c.text = hex,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(color: current == hex ? colors.text : colors.border, width: current == hex ? 2.5 : 1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _image(String label, String? url, {double width = 72, double height = 72}) {
    final c = AppColors.of(context);
    final placeholder = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
      child: Icon(Icons.image_outlined, color: c.textMuted),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        if (url == null)
          placeholder
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final primary = hexToColor(_c1.text) ?? c.primary;
    final secondary = hexToColor(_c2.text);
    return section(title: 'Brend', children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _image('Logo', widget.settings.logo),
          const SizedBox(width: 16),
          Expanded(child: _image('Muqova', widget.settings.cover, width: double.infinity)),
        ],
      ),
      const SizedBox(height: 6),
      Text('Rasmlarni web kabinetda yuklang', style: TextStyle(color: c.textMuted, fontSize: 12)),
      const SizedBox(height: 16),
      _colorField(_c1, 'Asosiy rang', 'brand_color'),
      const SizedBox(height: 16),
      _colorField(_c2, 'Ikkinchi rang', 'brand_color_2'),
      const SizedBox(height: 16),
      Row(
        children: [
          Text('Namuna:', style: TextStyle(color: c.textMuted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(999),
              border: secondary == null ? null : Border.all(color: secondary, width: 3),
            ),
            child: Text(widget.settings.name,
                style: TextStyle(
                  color: primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    ]);
  }
}
