import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/features/profile/providers.dart';
import 'package:bizcat/shared/widgets/bottom_bar.dart';
import 'package:bizcat/shared/widgets/buttons.dart';
import 'package:bizcat/shared/widgets/nav.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Ma'lumotlarim: name, birthday, gender, city (BIZCAT-SPEC §9.12).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  TextEditingController? _name;
  final _birthdayText = TextEditingController();
  final _phoneText = TextEditingController();

  @override
  void dispose() {
    _name?.dispose();
    _birthdayText.dispose();
    _phoneText.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday(ProfileEditState s) async {
    final now = DateTime.now();
    final last = DateTime(now.year - 10, now.month, now.day);
    final first = DateTime(1930);
    final b = s.birthday;
    var initial = b == null ? DateTime(now.year - 25, now.month, now.day) : DateTime(b.year, b.month, b.day);
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('uz'),
      firstDate: first,
      lastDate: last,
      initialDate: initial,
      helpText: "Tug'ilgan kun",
    );
    if (picked != null) ref.read(profileEditControllerProvider.notifier).setBirthday(LocalDate.fromDateTime(picked));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final ok = await ref.read(profileEditControllerProvider.notifier).save();
    if (!mounted) return;
    if (ok) {
      showSnack('Saqlandi.');
      popOrGo(context, AppRoutes.profile);
    } else {
      final error = ref.read(profileEditControllerProvider)?.error;
      if (error != null) showSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(profileEditControllerProvider);
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Ma'lumotlarim")),
        body: const LoadingView(kind: LoadingKind.detail),
      );
    }
    final ctrl = ref.read(profileEditControllerProvider.notifier);
    final name = _name ??= TextEditingController(text: s.name);
    _birthdayText.text = s.birthday == null ? '' : UzDates.dayMonthYear(s.birthday!);
    _phoneText.text = Phone.format(s.original.phone);
    final theme = Theme.of(context);
    final cityOptions = <String?>[null, ...kCities, if (s.city != null && !kCities.contains(s.city)) s.city];

    return Scaffold(
      appBar: AppBar(title: const Text("Ma'lumotlarim")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.l, BzSpace.gutter, BzSpace.xxxl),
        children: [
          TextField(
            key: const Key('profile-name'),
            controller: name,
            enabled: !s.saving,
            maxLength: 64,
            textCapitalization: TextCapitalization.words,
            onChanged: ctrl.setName,
            decoration: InputDecoration(labelText: 'Ism', counterText: '', errorText: s.fieldErrors['name']),
          ),
          const SizedBox(height: BzSpace.l),
          TextField(
            key: const Key('profile-birthday'),
            readOnly: true,
            enabled: !s.saving,
            controller: _birthdayText,
            onTap: () => unawaited(_pickBirthday(s)),
            decoration: InputDecoration(
              labelText: "Tug'ilgan kun",
              hintText: 'Tanlang',
              errorText: s.fieldErrors['birthday'],
              prefixIcon: const Icon(Icons.cake_outlined),
              suffixIcon: s.birthday == null
                  ? null
                  : IconButton(
                      tooltip: 'Tozalash',
                      icon: const Icon(Icons.close),
                      onPressed: () => ctrl.setBirthday(null),
                    ),
            ),
          ),
          const SizedBox(height: BzSpace.l),
          Text('Jins', style: theme.textTheme.labelLarge),
          const SizedBox(height: BzSpace.s),
          SegmentedButton<Gender>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Gender.male, label: Text('Erkak')),
              ButtonSegment(value: Gender.female, label: Text('Ayol')),
            ],
            selected: {?s.gender},
            onSelectionChanged: s.saving ? null : (v) => ctrl.setGender(v.isEmpty ? null : v.first),
          ),
          if (s.fieldErrors['gender'] != null)
            Padding(
              padding: const EdgeInsets.only(top: BzSpace.xs),
              child: Text(
                s.fieldErrors['gender']!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: BzSpace.xl),
          DropdownButtonFormField<String?>(
            key: const Key('profile-city'),
            initialValue: s.city,
            decoration: InputDecoration(labelText: 'Shahar', errorText: s.fieldErrors['city']),
            items: [
              for (final c in cityOptions) DropdownMenuItem<String?>(value: c, child: Text(c ?? "Ko'rsatilmagan")),
            ],
            onChanged: s.saving ? null : ctrl.setCity,
          ),
          const SizedBox(height: BzSpace.l),
          TextField(
            readOnly: true,
            enabled: false,
            controller: _phoneText,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              helperText: "Telefon raqamni o'zgartirib bo'lmaydi.",
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: 'Saqlash',
          loading: s.saving,
          onPressed: s.changed && !s.saving ? () => unawaited(_save()) : null,
        ),
      ),
    );
  }
}
