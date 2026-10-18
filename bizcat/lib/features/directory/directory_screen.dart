import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/features/directory/providers.dart';
import 'package:bizcat/features/directory/widgets/directory_filters.dart';
import 'package:bizcat/shared/widgets/business_cards.dart';
import 'package:bizcat/shared/widgets/states.dart';
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The Katalog tab: search, filters and the paged business list (BIZCAT-SPEC §9.4).
class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key, this.q, this.category, this.sort, this.focus = false});

  final String? q;
  final String? category;
  final String? sort;
  final bool focus;

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  static const _debounce = Duration(milliseconds: 350);
  static const _loadMoreWithin = 400.0;

  late final TextEditingController _search = TextEditingController(text: widget.q ?? '');
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _timer;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _initFilter();
    _recent = ref.read(appPrefsProvider).recentSearches;
    _focus.addListener(_onFocus);
    _scroll.addListener(_maybeLoadMore);
    if (widget.focus) WidgetsBinding.instance.addPostFrameCallback((_) => _focusSearch());
  }

  @override
  void didUpdateWidget(DirectoryScreen old) {
    super.didUpdateWidget(old);
    // The tab is kept alive: a new deep link (e.g. a home category) re-applies its params.
    if (old.q != widget.q || old.category != widget.category || old.sort != widget.sort) {
      _search.text = widget.q ?? '';
      _initFilter();
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
    if (widget.focus && !old.focus) _focusSearch();
  }

  /// Providers cannot change while widgets build, so the route params are applied right after.
  void _initFilter() {
    final ctrl = ref.read(directoryFilterProvider.notifier);
    final (q, category, sort) = (widget.q, widget.category, widget.sort);
    unawaited(
      Future.microtask(() {
        if (mounted) ctrl.init(q: q, category: category, sort: sort);
      }),
    );
  }

  void _focusSearch() {
    if (mounted) _focus.requestFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _onChanged(String value) {
    setState(() {});
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) ref.read(directoryFilterProvider.notifier).setQuery(value);
    });
  }

  void _onSubmitted(String value) {
    _timer?.cancel();
    ref.read(directoryFilterProvider.notifier).setQuery(value);
    final prefs = ref.read(appPrefsProvider);
    unawaited(
      prefs.addRecentSearch(value).then((_) {
        if (mounted) setState(() => _recent = prefs.recentSearches);
      }),
    );
  }

  void _pickRecent(String q) {
    _search.text = q;
    _search.selection = TextSelection.collapsed(offset: q.length);
    _onSubmitted(q);
    _focus.unfocus();
  }

  void _clearRecent() {
    unawaited(ref.read(appPrefsProvider).clearRecentSearches());
    setState(() => _recent = const []);
  }

  void _clearSearch() {
    _timer?.cancel();
    _search.clear();
    ref.read(directoryFilterProvider.notifier).setQuery('');
    setState(() {});
  }

  void _reset() {
    _timer?.cancel();
    _search.clear();
    ref.read(directoryFilterProvider.notifier).reset();
    setState(() {});
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels <= _loadMoreWithin) {
      final page = ref.read(directoryResultsProvider).value;
      if (page != null && page.hasMore && !page.loadingMore && page.moreError == null) {
        unawaited(ref.read(directoryResultsProvider.notifier).loadMore());
      }
    }
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(directoryResultsProvider);
      await ref.read(directoryResultsProvider.future);
    } on Object {
      // The error state shows it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(directoryResultsProvider);
    final showRecent = _focus.hasFocus && _search.text.isEmpty && _recent.isNotEmpty;

    // A short first page cannot scroll: check after layout whether more should load.
    ref.listen(directoryResultsProvider, (_, next) {
      if (next.hasValue) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: BzSpace.gutter,
        title: _SearchField(
          controller: _search,
          focusNode: _focus,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          onClear: _clearSearch,
        ),
        actions: [
          IconButton(
            key: const Key('directory-map'),
            tooltip: 'Xaritada',
            icon: const Icon(BzIcons.map),
            onPressed: () {
              final f = ref.read(directoryFilterProvider);
              unawaited(context.push(AppRoutes.mapWith(q: f.q, category: f.category)));
            },
          ),
          const SizedBox(width: BzSpace.xs),
        ],
      ),
      body: Column(
        children: [
          if (showRecent) RecentSearches(items: _recent, onPick: _pickRecent, onClear: _clearRecent),
          const DirectoryFilterRow(),
          Expanded(child: _body(context, results)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<DirectoryPage> results) {
    if (results.hasError && !results.isLoading) {
      final e = results.error!;
      void retry() => ref.invalidate(directoryResultsProvider);
      return isOffline(e) ? OfflineState(onRetry: retry) : ErrorState(message: errorText(e), onRetry: retry);
    }
    final data = results.value;
    if (data == null) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: LoadingView(kind: LoadingKind.cards, rows: 3),
      );
    }
    if (data.page.isEmpty) return _Empty(onReset: _reset);

    final theme = Theme.of(context);
    final items = data.page.items;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        key: const Key('directory-list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.xs, BzSpace.gutter, BzSpace.xxxl),
        itemCount: items.length + 2,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? BzSpace.s : BzSpace.m),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Text(
              '${data.page.meta.total} ta biznes',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            );
          }
          if (i == items.length + 1) return _Footer(page: data, onRetry: _retryMore);
          return BusinessCardTile(card: items[i - 1]);
        },
      ),
    );
  }

  void _retryMore() => unawaited(ref.read(directoryResultsProvider.notifier).loadMore());
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      key: const Key('directory-search'),
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Qidirish...',
        prefixIcon: const Icon(BzIcons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(tooltip: 'Tozalash', icon: const Icon(BzIcons.close), onPressed: onClear),
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(BzRadius.xl), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BzRadius.xl),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.page, required this.onRetry});

  final DirectoryPage page;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (page.moreError != null) {
      final theme = Theme.of(context);
      return Row(
        children: [
          Expanded(
            child: Text(
              errorText(page.moreError!),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      );
    }
    if (page.loadingMore || page.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(BzSpace.l),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    return ListView(
      padding: const EdgeInsets.only(top: BzSpace.xxl),
      children: [
        EmptyState(
          icon: BzIcons.searchEmpty,
          title: 'Hech narsa topilmadi',
          message: "Boshqa so'z yoki filtr bilan urinib ko'ring.",
          actionLabel: 'Filtrlarni tozalash',
          onAction: onReset,
        ),
        if (city != null)
          Center(
            child: TextButton(
              onPressed: () => unawaited(ref.read(cityProvider.notifier).set(null)),
              child: const Text('Barcha shaharlarda'),
            ),
          ),
      ],
    );
  }
}
