import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/ui.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One bottom-bar tab: its shell branch index, label and icons.
typedef ShellTab = ({int branch, String label, IconData icon, IconData selected});

/// The shell: Asosiy, Katalog, [map button], Bronlarim, Profil. Sevimlilar (branch 3) has no tab
/// of its own; it opens from Profil and the home page.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<ShellTab> tabs = [
    (branch: 0, label: 'Asosiy', icon: BzIcons.home, selected: BzIcons.homeBold),
    (branch: 1, label: 'Katalog', icon: BzIcons.catalog, selected: BzIcons.catalogBold),
    (branch: 2, label: 'Bronlarim', icon: BzIcons.bookings, selected: BzIcons.bookingsBold),
    (branch: 4, label: 'Profil', icon: BzIcons.profile, selected: BzIcons.profileBold),
  ];

  void _go(int branch) => navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BzBackground(child: navigationShell),
      bottomNavigationBar: BzBottomBar(
        current: navigationShell.currentIndex,
        onTab: _go,
        onMap: () => unawaited(context.push(AppRoutes.map)),
      ),
    );
  }
}

/// White bar with four labelled tabs and a raised round map button in the middle.
class BzBottomBar extends StatelessWidget {
  const BzBottomBar({super.key, required this.current, required this.onTab, required this.onMap});

  /// The current shell branch index.
  final int current;
  final ValueChanged<int> onTab;
  final VoidCallback onMap;

  static const double barHeight = 68;
  static const double fabSize = 64;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tabs = MainShell.tabs;

    Widget tab(ShellTab t) => Expanded(
      child: _TabItem(tab: t, selected: t.branch == current, onTap: () => onTab(t.branch)),
    );

    return SizedBox(
      height: barHeight + bottom + 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight + bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: BzColors.indigo.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Row(
                  children: [
                    tab(tabs[0]),
                    tab(tabs[1]),
                    const SizedBox(width: fabSize + 16),
                    tab(tabs[2]),
                    tab(tabs[3]),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 0, child: _MapButton(onTap: onMap)),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('tab-${tab.label}'),
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.selected : tab.icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Xarita',
      excludeSemantics: true,
      child: Container(
        width: BzBottomBar.fabSize,
        height: BzBottomBar.fabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BzColors.indigo700, BzColors.indigo],
          ),
          boxShadow: [
            BoxShadow(color: BzColors.indigo.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('tab-map'),
            onTap: onTap,
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(BzIcons.mapBold, color: BzColors.white, size: 28),
                Positioned(
                  right: 15,
                  top: 15,
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: BzColors.apricot, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
