import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/clients/actions.dart';
import 'package:tizbiz_biznes/features/clients/providers.dart';
import 'package:tizbiz_biznes/features/clients/widgets/client_tile.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// FilterChip per business client category; a toggle saves the full set immediately
/// (PUT /v1/clients/{id}/categories) and reverts on error.
class CategoriesEditor extends ConsumerStatefulWidget {
  const CategoriesEditor({super.key, required this.clientId, required this.selected});

  final int clientId;

  /// The client's categories from the detail.
  final List<ClientCategory> selected;

  @override
  ConsumerState<CategoriesEditor> createState() => _CategoriesEditorState();
}

class _CategoriesEditorState extends ConsumerState<CategoriesEditor> {
  late Set<int> _ids = {for (final c in widget.selected) c.id};
  bool _saving = false;

  @override
  void didUpdateWidget(CategoriesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving) _ids = {for (final c in widget.selected) c.id};
  }

  Future<void> _toggle(List<ClientCategory> all, int id, bool on) async {
    final before = _ids;
    final next = {...before};
    on ? next.add(id) : next.remove(id);
    setState(() {
      _ids = next;
      _saving = true;
    });
    // Full set in the business' category order.
    final ids = [
      for (final c in all)
        if (next.contains(c.id)) c.id,
    ];
    try {
      final saved = await ref.read(clientActionsProvider).setCategories(widget.clientId, ids);
      if (!mounted) return;
      setState(() => _ids = {for (final c in saved) c.id});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _ids = before);
      showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final value = ref.watch(clientCategoriesProvider);
    if (value.hasValue) {
      final all = value.requireValue;
      if (all.isEmpty) {
        return Text(
          "Mijoz kategoriyalari hali yaratilmagan (veb-kabinetda qo'shiladi).",
          style: t.bodySmall?.copyWith(color: c.textMuted),
        );
      }
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final cat in all)
            FilterChip(
              avatar: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: parseHexColor(cat.color) ?? c.textMuted, shape: BoxShape.circle),
              ),
              label: Text(cat.name),
              selected: _ids.contains(cat.id),
              onSelected: _saving ? null : (on) => _toggle(all, cat.id, on),
            ),
        ],
      );
    }
    if (value.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(errorText(value.error!), style: t.bodySmall?.copyWith(color: c.danger)),
          ),
          TextButton(onPressed: () => ref.invalidate(clientCategoriesProvider), child: const Text('Qayta urinish')),
        ],
      );
    }
    return const LinearProgressIndicator(minHeight: 2);
  }
}
