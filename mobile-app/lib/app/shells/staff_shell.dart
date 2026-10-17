import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/shells/manager_shell.dart';
import 'package:tizbiz_biznes/app/shells/nav_items.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';

/// Bottom navigation of staff members (own work through `/v1/me/*`).
class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeBusinessProvider);
    final fromCache = ref.watch(sessionProvider.select((s) => s is SessionSignedIn && s.fromCache));
    final items = active == null ? const <NavItem>[] : staffNavItems(active);
    return ShellScaffold(shell: shell, items: items, fromCache: fromCache, fallbackBranch: StaffBranch.profile);
  }
}
