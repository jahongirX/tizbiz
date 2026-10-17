import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/clients/providers.dart';
import 'package:tizbiz_biznes/features/clients/widgets/client_tile.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_biznes/shared/widgets/loading_view.dart';
import 'package:tizbiz_biznes/shared/widgets/paged_list_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Mijozlar (BIZNES-SPEC §9.6): search, segments, paged list.
class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(clientsQueryProvider.notifier).setSearch(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(clientsQueryProvider);
    final value = ref.watch(clientsPagedProvider(q));
    final notifier = ref.read(clientsPagedProvider(q).notifier);
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final filtered = q.search.isNotEmpty || q.segment.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Mijozlar')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'clients-new',
        tooltip: 'Yangi mijoz',
        onPressed: () => unawaited(context.push(Routes.clientNew)),
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Ism yoki telefon',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Tozalash',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _onSearch('');
                        },
                      ),
              ),
              onChanged: _onSearch,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final s in kClientSegments)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: q.segment == s.value,
                      onSelected: (_) => ref.read(clientsQueryProvider.notifier).setSegment(s.value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<Paged<Client>>(
              value: value,
              loading: const SkeletonList(),
              onRetry: () => ref.invalidate(clientsPagedProvider(q)),
              isEmpty: (p) => p.isEmpty,
              empty: RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 48),
                    filtered
                        ? const EmptyView(icon: Icons.search_off, title: 'Mijozlar topilmadi')
                        : EmptyView(
                            icon: Icons.people_outline,
                            title: "Hali mijozlar yo'q",
                            message: "Mijozlar birinchi yozuv bilan avtomatik qo'shiladi.",
                            action: FilledButton(
                              onPressed: () => unawaited(context.push(Routes.clientNew)),
                              child: const Text("Mijoz qo'shish"),
                            ),
                          ),
                  ],
                ),
              ),
              data: (page) => PagedListView<Client>(
                page: page,
                loadingMore: notifier.loadingMore,
                padding: const EdgeInsets.only(bottom: 88),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('${page.meta.total} ta mijoz', style: t.labelLarge?.copyWith(color: c.textMuted)),
                ),
                separator: Divider(height: 1, color: c.border),
                onRefresh: notifier.refresh,
                onLoadMore: () async {
                  try {
                    await notifier.loadMore();
                  } catch (e) {
                    if (context.mounted) showAppSnack(context, errorText(e), error: true);
                  }
                },
                itemBuilder: (context, cl) =>
                    ClientTile(client: cl, onTap: () => unawaited(context.push(Routes.client(cl.id)))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
