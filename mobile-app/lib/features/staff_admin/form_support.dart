import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Splits a write error into per-field texts (422 pointers in [known]) and a banner text.
({Map<String, String> fields, String? banner}) splitFormError(Object e, Set<String> known) {
  if (e is ApiException && e.isValidation && e.hasFieldErrors) {
    final fields = <String, String>{};
    final rest = <String>[];
    e.fieldErrors.forEach((k, v) => known.contains(k) ? fields[k] = v : rest.add(v));
    return (fields: fields, banner: rest.isEmpty ? null : rest.join('\n'));
  }
  return (fields: const {}, banner: errorText(e));
}

/// 403 on a write: let the session re-check the role.
void reportForbidden(WidgetRef ref, Object e) {
  if (e is ApiException && e.isForbidden) unawaited(ref.read(sessionProvider.notifier).onForbidden());
}

/// "O'zgarishlar saqlanmaydi. Chiqasizmi?" then leaves (pop, or [fallback]).
Future<void> confirmLeave(BuildContext context, String fallback) async {
  final ok = await confirmAction(
    context,
    title: "O'zgarishlar saqlanmaydi. Chiqasizmi?",
    confirmLabel: 'Chiqish',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// 24 h time picker.
Future<HmTime?> pickTime(BuildContext context, HmTime initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
  return t == null ? null : HmTime(t.hour, t.minute);
}
