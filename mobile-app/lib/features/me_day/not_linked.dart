import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kNotLinkedDetail = "Hisobingiz xodim profiliga bog'lanmagan.";

/// A /v1/me/* 404 that means "this login has no staff profile".
bool isNotLinkedError(Object? e) => e is ApiException && e.isNotFound && e.detail.trim() == kNotLinkedDetail;

/// [StaffNotLinkedView] that also refreshes the session once (`active.staff_id` changed server side).
class NotLinkedFromError extends ConsumerStatefulWidget {
  const NotLinkedFromError({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<NotLinkedFromError> createState() => _NotLinkedFromErrorState();
}

class _NotLinkedFromErrorState extends ConsumerState<NotLinkedFromError> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sessionProvider.notifier).onForbidden();
    });
  }

  @override
  Widget build(BuildContext context) => StaffNotLinkedView(compact: widget.compact);
}
