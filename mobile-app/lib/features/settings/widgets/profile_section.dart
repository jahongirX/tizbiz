import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/settings/widgets/section_form.dart';
import 'package:tizbiz_biznes/shared/widgets/phone_field.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// 2. "Biznes ma'lumotlari": name, phone, tagline, description.
class ProfileSection extends SettingsSectionWidget {
  const ProfileSection({super.key, required super.settings, super.onDirty});

  @override
  SettingsSectionState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends SettingsSectionState<ProfileSection> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _tagline;
  late final TextEditingController _description;

  @override
  Set<String> get keys => const {'name', 'phone', 'tagline', 'description'};

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _name = TextEditingController(text: s.name)..addListener(changed);
    _phone = TextEditingController(text: s.phone == null ? '' : Phone.formatLocal(s.phone))..addListener(changed);
    _tagline = TextEditingController(text: s.tagline ?? '')..addListener(changed);
    _description = TextEditingController(text: s.description ?? '')..addListener(changed);
    markClean();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _tagline.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  List<Object?> snapshot() => [_name.text.trim(), Phone.normalize(_phone.text), _tagline.text.trim(), _description.text.trim()];

  @override
  BookingSettings buildEdited(BookingSettings base) => base.copyWith(
        name: _name.text.trim(),
        phone: Phone.normalize(_phone.text),
        tagline: textOrNull(_tagline),
        description: textOrNull(_description),
      );

  @override
  Widget build(BuildContext context) => section(title: "Biznes ma'lumotlari", children: [
        TextFormField(
          controller: _name,
          enabled: !saving,
          maxLength: 128,
          decoration: InputDecoration(labelText: 'Nomi', errorText: fieldErrors['name'], counterText: ''),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Nomini kiriting' : null,
        ),
        const SizedBox(height: 12),
        PhoneField(
          controller: _phone,
          required: false,
          enabled: !saving,
          errorText: fieldErrors['phone'],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tagline,
          enabled: !saving,
          maxLength: 160,
          decoration: InputDecoration(labelText: 'Shior', errorText: fieldErrors['tagline']),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _description,
          enabled: !saving,
          maxLength: 2000,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: 'Tavsif', alignLabelWithHint: true, errorText: fieldErrors['description']),
        ),
      ]);
}
