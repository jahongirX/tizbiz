import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The 5-tab shell (Asosiy, Katalog, Bronlarim, Sevimlilar, Profil).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<({String label, IconData icon, IconData selected})> tabs = [
    (label: 'Asosiy', icon: Icons.home_outlined, selected: Icons.home),
    (label: 'Katalog', icon: Icons.search, selected: Icons.manage_search),
    (label: 'Bronlarim', icon: Icons.event_note_outlined, selected: Icons.event_note),
    (label: 'Sevimlilar', icon: Icons.favorite_border, selected: Icons.favorite),
    (label: 'Profil', icon: Icons.person_outline, selected: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) =>
              navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
          destinations: [
            for (final t in tabs)
              NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selected), label: t.label),
          ],
        ),
      ),
    );
  }
}
