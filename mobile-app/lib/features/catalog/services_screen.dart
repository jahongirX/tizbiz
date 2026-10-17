import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_biznes/app/routes.dart';
import 'package:tizbiz_biznes/app/theme/app_colors.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/features/catalog/widgets/service_tile.dart';
import 'package:tizbiz_biznes/shared/data/catalog_data.dart';
import 'package:tizbiz_biznes/shared/widgets/async_body.dart';
import 'package:tizbiz_biznes/shared/widgets/empty_view.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// One titled group of services.
typedef ServiceSection = ({String title, List<Service> items});

/// Sections per category (in the given category order) then "Kategoriyasiz"; empty sections are
/// dropped; inactive services only when [showInactive].
List<ServiceSection> groupServices(List<Service> services, List<ServiceCategory> categories, {bool showInactive = false}) {
  final visible = [for (final s in services) if (showInactive || s.isActive) s];
  final known = {for (final c in categories) c.id};
  final sections = <ServiceSection>[
    for (final c in categories) (title: c.name, items: [for (final s in visible) if (s.categoryId == c.id) s]),
    (
      title: 'Kategoriyasiz',
      items: [for (final s in visible) if (s.categoryId == null || !known.contains(s.categoryId)) s],
    ),
  ];
  return [for (final s in sections) if (s.items.isNotEmpty) s];
}

/// Xizmatlar / Menyu / Buyumlar (BIZNES-SPEC §9.7).
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  bool _showInactive = false;

  Future<void> _refresh() {
    ref.invalidate(serviceCategoriesProvider);
    return ref.refresh(servicesListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeBusinessProvider);
    final engine = a?.engine ?? Engine.slot;
    final services = ref.watch(servicesListProvider);
    final categories = ref.watch(serviceCategoriesProvider);
    final c = AppColors.of(context);
    // Category errors are not fatal: everything then shows under "Kategoriyasiz".
    final waitingCategories = categories.isLoading && !categories.hasValue && !categories.hasError;
    return Scaffold(
      appBar: AppBar(
        title: Text(engine.servicesTerm),
        actions: [
          TextButton.icon(
            onPressed: () => unawaited(context.push(Routes.serviceCategories)),
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Kategoriyalar'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'service-new',
        onPressed: () => unawaited(context.push(Routes.serviceNew)),
        icon: const Icon(Icons.add),
        label: const Text("Qo'shish"),
      ),
      body: AsyncBody<List<Service>>(
        value: waitingCategories ? const AsyncLoading<List<Service>>() : services,
        onRetry: () => ref.invalidate(servicesListProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          icon: Icons.design_services_outlined,
          title: "Hali xizmatlar yo'q",
          message: "Mijozlar bron qilishi uchun ${engine.servicesTerm.toLowerCase()} ro'yxatini to'ldiring.",
          action: FilledButton.icon(
            onPressed: () => unawaited(context.push(Routes.serviceNew)),
            icon: const Icon(Icons.add),
            label: const Text("Xizmat qo'shish"),
          ),
        ),
        data: (list) {
          final sections = groupServices(list, categories.value ?? const [], showInactive: _showInactive);
          final inactive = list.where((s) => !s.isActive).length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                SwitchListTile(
                  title: const Text("Nofaollarni ko'rsatish"),
                  subtitle: inactive == 0 ? null : Text('$inactive ta nofaol'),
                  value: _showInactive,
                  onChanged: (v) => setState(() => _showInactive = v),
                ),
                if (sections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Faol xizmat yo'q. Nofaollarni ko'rsating yoki yangisini qo'shing.", textAlign: TextAlign.center),
                  ),
                for (final s in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      '${s.title} · ${s.items.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c.textMuted),
                    ),
                  ),
                  for (final item in s.items)
                    ServiceTile(
                      service: item,
                      engine: engine,
                      onTap: () => unawaited(context.push(Routes.service(item.id))),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
