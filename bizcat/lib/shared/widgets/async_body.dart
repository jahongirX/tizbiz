import 'package:bizcat/core/errors.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Renders an [AsyncValue]: loading -> [loading] or [LoadingView]; error -> [OfflineState] /
/// [ErrorState]; data + [isEmpty] -> [empty]; data -> [builder].
///
/// While refreshing with a previous value it keeps showing the data.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v.hasError && !v.isLoading) {
      final e = v.error!;
      return isOffline(e) ? OfflineState(onRetry: onRetry) : ErrorState(message: errorText(e), onRetry: onRetry);
    }
    if (v.hasValue) {
      final data = v.requireValue;
      if (isEmpty != null && empty != null && isEmpty!(data)) return empty!;
      return builder(data);
    }
    return loading ?? const LoadingView();
  }
}
