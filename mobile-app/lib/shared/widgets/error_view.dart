import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Error state for a screen/section without data (BIZNES-SPEC §7.4).
///
/// - offline: "Internet aloqasi yo'q" + "Qayta urinish";
/// - 403: "Bu bo'lim uchun ruxsatingiz yo'q." and `session.onForbidden()` (role may have changed);
/// - 404: "Topilmadi.";
/// - 401: logs out after the frame (fallback for 401s the ApiClient hook cannot see);
/// - other: `e.message` + "Qayta urinish".
class ErrorView extends ConsumerStatefulWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  ConsumerState<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends ConsumerState<ErrorView> {
  Object? _handled;

  @override
  void initState() {
    super.initState();
    _react();
  }

  @override
  void didUpdateWidget(ErrorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) _react();
  }

  void _react() {
    final e = widget.error;
    if (identical(_handled, e) || e is! ApiException) return;
    _handled = e;
    if (e.isUnauthorized || e.isForbidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final session = ref.read(sessionProvider.notifier);
        if (e.isUnauthorized) {
          session.onUnauthorized(e);
        } else {
          session.onForbidden();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.error;
    final retry = widget.onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Qayta urinish'),
          );
    if (e is ApiException) {
      if (e.isNetwork) {
        return EmptyView(
          icon: Icons.wifi_off,
          title: "Internet aloqasi yo'q",
          message: "Ulanishni tekshirib, qayta urinib ko'ring.",
          action: retry,
        );
      }
      if (e.isForbidden) {
        return const EmptyView(icon: Icons.lock_outline, title: "Bu bo'lim uchun ruxsatingiz yo'q.");
      }
      if (e.isNotFound) {
        return EmptyView(icon: Icons.search_off, title: 'Topilmadi.', action: retry);
      }
      if (e.isUnauthorized) {
        return const EmptyView(icon: Icons.lock_clock_outlined, title: kSessionExpiredMessage);
      }
      return EmptyView(icon: Icons.error_outline, title: e.message, action: retry);
    }
    return EmptyView(icon: Icons.error_outline, title: 'Xatolik yuz berdi.', action: retry);
  }
}

/// User-facing text of any error (ApiException.message, else a generic one).
String errorText(Object error) => error is ApiException ? error.message : 'Xatolik yuz berdi.';
