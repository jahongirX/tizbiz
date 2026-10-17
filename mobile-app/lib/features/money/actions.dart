import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Money mutations (BIZNES-SPEC §9.9).
final class MoneyActions {
  MoneyActions(this._ref);

  final Ref _ref;

  /// PATCH /v1/staff/{id} {"commission_percent": percent}; bumps the staff revision (payroll refetches).
  Future<Staff> setCommission(int staffId, int percent) async {
    final staff = await _ref.read(apiClientProvider).patch(
          Endpoints.staffById(staffId),
          body: {'commission_percent': percent},
          decode: (d) => Staff.fromJson(JsonRead.object(d)),
        );
    bump(_ref, staffRevisionProvider);
    return staff;
  }
}

final moneyActionsProvider = Provider<MoneyActions>(MoneyActions.new);
