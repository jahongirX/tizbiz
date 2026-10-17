import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Client mutations (BIZNES-SPEC §9.6). Bodies use the `Client.toInput()` keys:
/// name, phone, email, birthday, notes, tags. Every call bumps the clients revision.
class ClientActions {
  ClientActions(this.ref);

  final Ref ref;

  ApiClient get _api => ref.read(apiClientProvider);

  Client _client(dynamic d) => Client.fromJson(JsonRead.object(d));

  /// POST /v1/clients -> 201 Client.
  Future<Client> create(Map<String, dynamic> body) async {
    final c = await _api.post<Client>(Endpoints.clients, body: body, decode: _client);
    bump(ref, clientsRevisionProvider);
    return c;
  }

  /// PATCH /v1/clients/{id} -> Client.
  Future<Client> update(int id, Map<String, dynamic> body) async {
    final c = await _api.patch<Client>(Endpoints.client(id), body: body, decode: _client);
    bump(ref, clientsRevisionProvider);
    return c;
  }

  /// DELETE /v1/clients/{id} -> 204 (history is kept on the server).
  Future<void> delete(int id) async {
    await _api.delete<void>(Endpoints.client(id));
    bump(ref, clientsRevisionProvider);
  }

  /// PUT /v1/clients/{id}/categories {"category_ids": [...]} -> the client's categories.
  Future<List<ClientCategory>> setCategories(int id, List<int> ids) async {
    final list = await _api.put<List<ClientCategory>>(
      Endpoints.clientCategoriesOf(id),
      body: {'category_ids': ids},
      decode: (d) => JsonRead.list(d, ClientCategory.fromJson),
    );
    bump(ref, clientsRevisionProvider);
    return list;
  }
}

final clientActionsProvider = Provider<ClientActions>(ClientActions.new);
