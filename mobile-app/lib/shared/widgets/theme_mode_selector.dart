import 'package:material_ui/material_ui.dart';

/// "Tizim / Yorug' / Qorong'i" segmented control (Ko'proq menu and the staff Profil screen).
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key, required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Tizim'), icon: Icon(Icons.brightness_auto_outlined)),
          ButtonSegment(value: ThemeMode.light, label: Text("Yorug'"), icon: Icon(Icons.light_mode_outlined)),
          ButtonSegment(value: ThemeMode.dark, label: Text("Qorong'i"), icon: Icon(Icons.dark_mode_outlined)),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}
