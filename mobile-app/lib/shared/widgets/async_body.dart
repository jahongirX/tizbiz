import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/stale_banner.dart';

/// The standard screen states (BIZNES-SPEC §7.4) for one [AsyncValue]:
/// - loading without data: [loading] (default [LoadingView]);
/// - data: [data], or [empty] when [isEmpty] says so; while refetching, a 2 px progress bar on top;
/// - error without data: [ErrorView];
/// - error with old data: the data plus a [StaleBanner].
///
/// [expand] (default true) fills the parent's height (screen bodies). Use `expand: false` for a
/// section inside a scroll view.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.loading,
    this.expand = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v.hasValue) {
      final d = v.requireValue;
      final content = (isEmpty?.call(d) ?? false)
          ? (empty ?? const EmptyView(icon: Icons.inbox_outlined, title: "Ma'lumot yo'q"))
          : data(d);
      final refreshing = v.isLoading;
      final stale = v.hasError && !v.isLoading;
      if (!refreshing && !stale) return content;
      return Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (refreshing) const LinearProgressIndicator(minHeight: 2),
          if (stale) StaleBanner(error: v.error!, onRetry: onRetry),
          if (expand) Expanded(child: content) else content,
        ],
      );
    }
    if (v.hasError) {
      return ErrorView(error: v.error!, onRetry: onRetry);
    }
    return loading ?? const LoadingView();
  }
}
