import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/features/catalog/actions.dart';
import 'package:tizbiz_biznes/features/catalog/form_support.dart';
import 'package:tizbiz_biznes/features/catalog/widgets/category_dialog.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/app_snack.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/confirm_dialog.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_biznes/shared/widgets/error_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Service categories: list sorted by `sort`, add/edit dialog, delete.
class ServiceCategoriesScreen extends ConsumerWidget {
  const ServiceCategoriesScreen({super.key});

  int _nextSort(List<ServiceCategory> list) => list.isEmpty ? 1 : list.map((c) => c.sort).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _edit(BuildContext context, WidgetRef ref, {ServiceCategory? category}) async {
    final list = ref.read(serviceCategoriesProvider).value ?? const <ServiceCategory>[];
    final saved = await CategoryDialog.show(context, category: category, nextSort: _nextSort(list));
    if (saved != null && context.mounted) {
      showAppSnack(context, category == null ? "Kategoriya qo'shildi" : 'Saqlandi');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ServiceCategory category) async {
    final ok = await confirmAction(
      context,
      title: "Kategoriya o'chirilsinmi? Undagi xizmatlar kategoriyasiz qoladi.",
      message: category.name,
      confirmLabel: "O'chirish",
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(catalogActionsProvider).deleteCategory(category.id);
      if (context.mounted) showAppSnack(context, "Kategoriya o'chirildi");
    } on Object catch (e) {
      reportForbidden(ref, e);
      if (context.mounted) showAppSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final async = ref.watch(serviceCategoriesProvider);
    final services = ref.watch(servicesListProvider).value ?? const <Service>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriyalar')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'category-new',
        onPressed: () => unawaited(_edit(context, ref)),
        icon: const Icon(Icons.add),
        label: const Text("Qo'shish"),
      ),
      body: AsyncBody<List<ServiceCategory>>(
        value: async,
        onRetry: () => ref.invalidate(serviceCategoriesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          icon: Icons.folder_open_outlined,
          title: "Hali kategoriyalar yo'q",
          message: "Xizmatlarni guruhlash uchun kategoriya qo'shing.",
          action: FilledButton.icon(
            onPressed: () => unawaited(_edit(context, ref)),
            icon: const Icon(Icons.add),
            label: const Text("Kategoriya qo'shish"),
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(serviceCategoriesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
            itemBuilder: (context, i) {
              final cat = list[i];
              final count = services.where((s) => s.categoryId == cat.id).length;
              return ListTile(
                onTap: () => unawaited(_edit(context, ref, category: cat)),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: c.primarySoft,
                  foregroundColor: c.primary,
                  child: Text('${cat.sort}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                title: Text(cat.name),
                subtitle: Text('$count ta xizmat'),
                trailing: IconButton(
                  tooltip: "O'chirish",
                  icon: Icon(Icons.delete_outline, color: c.danger),
                  onPressed: () => unawaited(_delete(context, ref, cat)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
