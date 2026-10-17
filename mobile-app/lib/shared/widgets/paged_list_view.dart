import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Infinite list over a [Paged] value: pull-to-refresh, and [onLoadMore] 300 px before the end
/// while `page.hasMore`.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.page,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    this.loadingMore = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.separator,
    this.header,
  });

  final Paged<T> page;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final bool loadingMore;
  final EdgeInsets padding;
  final Widget? separator;

  /// Scrolls with the list (e.g. a summary card).
  final Widget? header;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  bool _requested = false;

  @override
  void didUpdateWidget(PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.page, widget.page) || oldWidget.loadingMore != widget.loadingMore) {
      _requested = widget.loadingMore;
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (!_requested && !widget.loadingMore && widget.page.hasMore && n.metrics.extentAfter < 300) {
      _requested = true;
      widget.onLoadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.page.items;
    final hasHeader = widget.header != null;
    final footer = widget.loadingMore || widget.page.hasMore;
    final count = items.length + (hasHeader ? 1 : 0) + (footer ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: count,
          itemBuilder: (context, index) {
            var i = index;
            if (hasHeader) {
              if (i == 0) return widget.header!;
              i -= 1;
            }
            if (i >= items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final tile = widget.itemBuilder(context, items[i]);
            if (widget.separator == null || i == items.length - 1) return tile;
            return Column(mainAxisSize: MainAxisSize.min, children: [tile, widget.separator!]);
          },
        ),
      ),
    );
  }
}
