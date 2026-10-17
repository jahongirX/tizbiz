import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/data/directory_providers.dart';
import 'package:bizcat/data/directory_query.dart';
import 'package:bizcat/features/directory/providers.dart';
import 'package:bizcat/shared/widgets/category_icon.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The horizontal filter row: city, sort, then the category chips.
class DirectoryFilterRow extends ConsumerWidget {
  const DirectoryFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(directoryFilterProvider);
    final ctrl = ref.read(directoryFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      // Few chips: a plain Row (not lazy) so every chip exists for focus and tests.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.xs),
        child: Row(
          children: [
            ActionChip(
              key: const ValueKey('dir-city'),
              avatar: Icon(Icons.place_outlined, size: 18, color: scheme.primary),
              label: Text(cityLabel(filter.city)),
              onPressed: () => unawaited(context.push(AppRoutes.city)),
            ),
            const SizedBox(width: BzSpace.s),
            ActionChip(
              key: const ValueKey('dir-sort'),
              avatar: Icon(Icons.sort_rounded, size: 18, color: scheme.primary),
              label: Text(directorySortLabel(filter.sort)),
              onPressed: () => unawaited(_pickSort(context, ref, filter.sort)),
            ),
            const SizedBox(width: BzSpace.s),
            ChoiceChip(
              label: const Text('Barchasi'),
              selected: filter.category == null,
              onSelected: (_) => ctrl.setCategory(null),
            ),
            for (final c in categories) ...[
              const SizedBox(width: BzSpace.s),
              ChoiceChip(
                key: ValueKey('dir-cat-${c.key}'),
                label: Text(categoryShortLabel(c.label)),
                selected: filter.category == c.key,
                onSelected: (_) => ctrl.setCategory(filter.category == c.key ? null : c.key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickSort(BuildContext context, WidgetRef ref, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(BzSpace.gutter, 0, BzSpace.gutter, BzSpace.s),
                child: Text('Saralash', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final s in DirectoryQuery.sorts)
                ListTile(
                  key: ValueKey('sort-$s'),
                  leading: Icon(
                    s == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: s == current ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  title: Text(directorySortLabel(s)),
                  onTap: () => Navigator.of(context).pop(s),
                ),
              const SizedBox(height: BzSpace.s),
            ],
          ),
        );
      },
    );
    if (picked != null) ref.read(directoryFilterProvider.notifier).setSort(picked);
  }
}

/// `So'nggi qidiruvlar` chips with a `Tozalash` action.
class RecentSearches extends StatelessWidget {
  const RecentSearches({super.key, required this.items, required this.onPick, required this.onClear});

  final List<String> items;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, BzSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text("So'nggi qidiruvlar", style: theme.textTheme.titleSmall)),
              TextButton(onPressed: onClear, child: const Text('Tozalash')),
            ],
          ),
          Wrap(
            spacing: BzSpace.s,
            runSpacing: BzSpace.s,
            children: [
              for (final s in items)
                ActionChip(avatar: const Icon(Icons.history, size: 18), label: Text(s), onPressed: () => onPick(s)),
            ],
          ),
        ],
      ),
    );
  }
}
