import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Service and service-category writes (BIZNES-SPEC §9.7). Every write bumps services.
final class CatalogActions {
  CatalogActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  static Service _service(dynamic d) => Service.fromJson(JsonRead.object(d));
  static ServiceCategory _category(dynamic d) => ServiceCategory.fromJson(JsonRead.object(d));

  void _bump() => bump(_ref, servicesRevisionProvider);

  /// POST /v1/services (201). Body keys from `Service.toInput()`.
  Future<Service> createService(Map<String, dynamic> body) async {
    final s = await _api.post<Service>(Endpoints.services, body: body, decode: _service);
    _bump();
    return s;
  }

  /// PATCH /v1/services/{id}.
  Future<Service> updateService(int id, Map<String, dynamic> body) async {
    final s = await _api.patch<Service>(Endpoints.service(id), body: body, decode: _service);
    _bump();
    return s;
  }

  /// DELETE /v1/services/{id} (soft: is_active=false).
  Future<void> deactivateService(int id) async {
    await _api.delete<Object?>(Endpoints.service(id));
    _bump();
  }

  /// POST /v1/service-categories.
  Future<ServiceCategory> createCategory({required String name, int sort = 0}) async {
    final c = await _api.post<ServiceCategory>(Endpoints.serviceCategories,
        body: {'name': name, 'sort': sort}, decode: _category);
    _bump();
    return c;
  }

  /// PATCH /v1/service-categories/{id}.
  Future<ServiceCategory> updateCategory(int id, {String? name, int? sort}) async {
    final c = await _api.patch<ServiceCategory>(Endpoints.serviceCategory(id),
        body: {'name': ?name, 'sort': ?sort}, decode: _category);
    _bump();
    return c;
  }

  /// DELETE /v1/service-categories/{id} (hard; its services become uncategorised).
  Future<void> deleteCategory(int id) async {
    await _api.delete<Object?>(Endpoints.serviceCategory(id));
    _bump();
  }
}

final catalogActionsProvider = Provider<CatalogActions>(CatalogActions.new);
