import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('forRole', () {
    expect(Permissions.forRole('business_owner'), equals(Permissions.all));
    expect(Permissions.all.length, 16);
    final admin = Permissions.forRole('business_admin');
    expect(admin.length, 15);
    expect(admin, contains(Permissions.finance));
    expect(admin, isNot(contains(Permissions.teamManage)));
    expect(Permissions.forRole('staff'), equals(['orders', 'me']));
    expect(Permissions.forRole(null), isEmpty);
    expect(Permissions.forRole('consumer'), isEmpty);
  });
}
