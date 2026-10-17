import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/staff_not_linked_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

const kMeNotLinkedDetail = "Hisobingiz xodim profiliga bog'lanmagan.";

/// A /v1/me/* 404 that means "this login has no staff profile".
bool isMeNotLinked(Object? e) => e is ApiException && e.isNotFound && e.detail.trim() == kMeNotLinkedDetail;

/// [StaffNotLinkedView] that refreshes the session once (`active.staff_id` changed server side).
class MeNotLinkedView extends ConsumerStatefulWidget {
  const MeNotLinkedView({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<MeNotLinkedView> createState() => _MeNotLinkedViewState();
}

class _MeNotLinkedViewState extends ConsumerState<MeNotLinkedView> {
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
