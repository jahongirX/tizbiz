import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_biznes/core/api_providers.dart';
import 'package:tizbiz_biznes/shared/data/revisions.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Staff, working-hours and time-off writes (BIZNES-SPEC §9.8). Staff writes bump staff,
/// schedule writes bump schedule. Errors are [ApiException]s; screens show them.
final class StaffActions {
  StaffActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  static Staff _staff(dynamic d) => Staff.fromJson(JsonRead.object(d));

  /// POST /v1/staff (201). Body from `Staff.toInput()`.
  Future<Staff> create(Map<String, dynamic> body) async {
    final s = await _api.post<Staff>(Endpoints.staff, body: body, decode: _staff);
    bump(_ref, staffRevisionProvider);
    return s;
  }

  /// PATCH /v1/staff/{id}.
  Future<Staff> update(int id, Map<String, dynamic> body) async {
    final s = await _api.patch<Staff>(Endpoints.staffById(id), body: body, decode: _staff);
    bump(_ref, staffRevisionProvider);
    return s;
  }

  /// DELETE /v1/staff/{id} (soft: is_active=false).
  Future<void> deactivate(int id) async {
    await _api.delete<Object?>(Endpoints.staffById(id));
    bump(_ref, staffRevisionProvider);
  }

  /// PUT /v1/staff/{id}/working-hours `{"items":[...]}`; replaces the whole week.
  Future<List<WorkingHours>> saveWorkingHours(int staffId, WorkingHoursInput input) async {
    final rows = await _api.put<List<WorkingHours>>(
      Endpoints.workingHours(staffId),
      body: input.toJson(),
      decode: (d) => JsonRead.list(d, WorkingHours.fromJson),
    );
    bump(_ref, scheduleRevisionProvider);
    return rows;
  }

  /// POST /v1/staff/{id}/time-off (201).
  Future<TimeOff> addTimeOff(int staffId, TimeOffInput input) async {
    final t = await _api.post<TimeOff>(
      Endpoints.timeOff(staffId),
      body: input.toJson(),
      decode: (d) => TimeOff.fromJson(JsonRead.object(d)),
    );
    bump(_ref, scheduleRevisionProvider);
    return t;
  }

  /// DELETE /v1/staff/{id}/time-off/{tid}.
  Future<void> deleteTimeOff(int staffId, int id) async {
    await _api.delete<Object?>(Endpoints.timeOffItem(staffId, id));
    bump(_ref, scheduleRevisionProvider);
  }
}

final staffActionsProvider = Provider<StaffActions>(StaffActions.new);
