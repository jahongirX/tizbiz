import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('GET /v1/team', () {
    final list = dataList(teamListJson).map(TeamMember.fromJson).toList();
    expect(list, hasLength(2));
    expect(list.first.role, BizRole.owner);
    expect(list.first.staffId, isNull);
    expect(list.last.staffId, 2);
    expect(list.last.name, 'Usta Jahongir');
    for (final m in list) {
      expectFixedPoint(m, (x) => x.toJson(), TeamMember.fromJson);
    }
  });

  test('PATCH response has no name/phone', () {
    final m = TeamMember.fromJson(dataMap(teamPatchJson));
    expect(m.userId, 31);
    expect(m.role, BizRole.staff);
    expect(m.staffId, 2);
    expect(m.name, isNull);
    expect(m.phone, isNull);
    expectFixedPoint(m, (x) => x.toJson(), TeamMember.fromJson);
  });
}
