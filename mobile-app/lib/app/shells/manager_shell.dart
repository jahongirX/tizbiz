import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/shells/nav_items.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/offline_banner.dart';

/// Bottom navigation of owners and administrators.
class ManagerShell extends ConsumerWidget {
  const ManagerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    final fromCache = ref.watch(sessionProvider.select((s) => s is SessionSignedIn && s.fromCache));
    final items = active == null ? const <NavItem>[] : managerNavItems(active);
    return ShellScaffold(shell: shell, items: items, fromCache: fromCache, fallbackBranch: ManagerBranch.more);
  }
}

/// Shared body of both shells: offline banner + branch stack + NavigationBar.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.shell,
    required this.items,
    required this.fromCache,
    required this.fallbackBranch,
  });

  final StatefulNavigationShell shell;
  final List<NavItem> items;
  final bool fromCache;
  final int fallbackBranch;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (fromCache) const OfflineBanner(),
        Expanded(child: shell),
      ],
    );
    if (items.length < 2) return Scaffold(body: body);
    final selected = selectedNavIndex(items, shell.currentIndex, fallbackBranch: fallbackBranch);
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          final branch = items[i].branch;
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        destinations: [
          for (final n in items)
            NavigationDestination(icon: Icon(n.icon), selectedIcon: Icon(n.selectedIcon), label: n.label),
        ],
      ),
    );
  }
}
