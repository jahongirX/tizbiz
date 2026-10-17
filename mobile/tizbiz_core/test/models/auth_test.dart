import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('login (BP 4.1)', () {
    final s = AuthSession.fromJson(dataMap(loginJson));
    expect(s.token, startsWith('eyJ0eXAi'));
    expect(s.expiresAt, Dates.fromUnix(1792818720));
    expect(s.user.id, 4);
    expect(s.user.isSuperadmin, isFalse);
    expect(s.user.status, 10);
    expect(s.active.staffId, isNull);
    expect(s.active.permissions, contains(Permissions.teamManage));
    expect(s.active.isOwner, isTrue);
    expect(s.active.isManager, isTrue);
    expect(s.active.can(Permissions.finance), isTrue);
    expect(s.businesses.first.engine, Engine.slot);
    expect(s.businesses.first.role, BizRole.owner);
    expect(s.activeBusiness?.slug, 'shox-barber');
    expectFixedPoint(s, (x) => x.toJson(), AuthSession.fromJson);
  });

  test('live login: is_superadmin 0, no NEW keys', () {
    final s = AuthSession.fromJson(dataMap(loginLiveJson));
    expect(s.user.isSuperadmin, isFalse);
    expect(s.expiresAt, isNull);
    expect(s.active.staffId, isNull);
    expect(s.active.role, BizRole.staff);
    expect(s.active.isStaff, isTrue);
    expect(s.active.hasStaffProfile, isFalse);
    expect(s.active.permissions, ['orders', 'me']);
    expect(s.businesses.single.engine, Engine.slot);
    expectFixedPoint(s, (x) => x.toJson(), AuthSession.fromJson);
  });

  test('me / switch', () {
    final login = AuthSession.fromJson(dataMap(loginJson));
    final me = AuthMe.fromJson(dataMap(authMeJson));
    expect(me.active.staffId, 7);
    expect(me.businesses, hasLength(2));
    expect(me.user.isSuperadmin, isFalse);
    expectFixedPoint(me, (x) => x.toJson(), AuthMe.fromJson);

    final withMe = login.withMe(me);
    expect(withMe.token, login.token);
    expect(withMe.user.id, 31);
    expect(withMe.active.role, BizRole.staff);
    expect(withMe.businesses, hasLength(2));

    final sw = SwitchResult.fromJson(dataMap(switchJson));
    expect(sw.active.businessId, 3);
    expectFixedPoint(sw, (x) => x.toJson(), SwitchResult.fromJson);
    final switched = withMe.withSwitch(sw);
    expect(switched.token, 'eyJ.switched.token');
    expect(switched.active.businessId, 3);
    expect(switched.active.staffId, 12);
    expect(switched.activeBusiness?.slug, 'aziza-tortlari');
    expect(switched.user.id, 31);
  });

  test('no active business', () {
    final a = ActiveContext.fromJson(const {'business_id': null, 'role': null});
    expect(a.hasBusiness, isFalse);
    expect(a.role, isNull);
    expect(a.permissions, isEmpty);
    expect(a.isManager, isFalse);
  });
}
