import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Shown by soft-auth screens when signed out: an [EmptyState] with `Kirish`.
class LoginPromptView extends StatelessWidget {
  const LoginPromptView({super.key, required this.title, this.message, required this.from, this.icon = BzIcons.lock});

  final String title;
  final String? message;

  /// Where to return after the login, e.g. AppRoutes.bookings.
  final String from;
  final IconData icon;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    title: title,
    message: message,
    actionLabel: 'Kirish',
    onAction: () => unawaited(context.push(AppRoutes.loginWith(from: from))),
  );
}
