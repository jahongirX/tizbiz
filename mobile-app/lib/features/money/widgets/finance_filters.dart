import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/features/money/providers.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

String _typeLabel(String t) => FinanceTransaction(id: 0, type: t).typeLabel;
String _statusLabel(String s) => FinanceTransaction(id: 0, status: s).statusLabel;

/// Filter chips (type, status, provider); each opens a picker sheet bound to [financeFiltersProvider].
class FinanceFilterChips extends ConsumerWidget {
  const FinanceFilterChips({super.key});

  Future<void> _pick(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String Function(String) label,
    required String? current,
    required void Function(String?) onPicked,
  }) async {
    final picked = await showModalBottomSheet<({String? value})>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final o in <String?>[null, ...options])
              ListTile(
                title: Text(o == null ? 'Hammasi' : label(o)),
                trailing: o == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop((value: o)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(financeFiltersProvider);
    final n = ref.read(financeFiltersProvider.notifier);
    Widget chip(String name, String? value, String Function(String) label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(value == null ? name : '$name: ${label(value)}'),
            selected: value != null,
            onSelected: (_) => onTap(),
          ),
        );
    final any = f.type != null || f.status != null || f.provider != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          chip('Turi', f.type, _typeLabel, () => _pick(context,
              title: 'Turi', options: kFinanceTypes, label: _typeLabel, current: f.type, onPicked: n.setType)),
          chip('Holati', f.status, _statusLabel, () => _pick(context,
              title: 'Holati', options: kFinanceStatuses, label: _statusLabel, current: f.status, onPicked: n.setStatus)),
          chip("To'lov tizimi", f.provider, providerLabel, () => _pick(context,
              title: "To'lov tizimi",
              options: kFinanceProviders,
              label: providerLabel,
              current: f.provider,
              onPicked: n.setProvider)),
          if (any) TextButton(onPressed: n.clear, child: const Text('Tozalash')),
        ],
      ),
    );
  }
}
