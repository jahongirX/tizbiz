import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Manager only (staff tokens get 403 here). All staff rows incl. inactive (server orders by name).
final staffListProvider = FutureProvider.autoDispose<List<Staff>>((ref) async {
  requireActive(ref);
  ref.watch(staffRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.staff, Staff.fromJson, cancelToken: cancel);
});

/// Active staff only (pickers, timetable).
final activeStaffProvider = Provider.autoDispose<AsyncValue<List<Staff>>>(
  (ref) => ref.watch(staffListProvider).whenData((list) => [for (final s in list) if (s.isActive) s]),
);

/// Manager only. All services incl. inactive.
final servicesListProvider = FutureProvider.autoDispose<List<Service>>((ref) async {
  requireActive(ref);
  ref.watch(servicesRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(apiClientProvider).getList(Endpoints.services, Service.fromJson, cancelToken: cancel);
});

/// Manager only. Sorted by `sort`, then `id`.
final serviceCategoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>((ref) async {
  requireActive(ref);
  ref.watch(servicesRevisionProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final list = await ref
      .watch(apiClientProvider)
      .getList(Endpoints.serviceCategories, ServiceCategory.fromJson, cancelToken: cancel);
  return [...list]..sort((a, b) => a.sort != b.sort ? a.sort.compareTo(b.sort) : a.id.compareTo(b.id));
});
