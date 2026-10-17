import 'package:flutter_test/flutter_test.dart';
import 'package:tizbiz_biznes/app/shells/nav_items.dart';
import 'package:tizbiz_biznes/core/session/active_business.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';

ActiveBusiness _active({Engine engine = Engine.slot, BizRole role = BizRole.owner, int? staffId}) =>
    ActiveBusiness.fromSession(fxAuthSession(engine: engine, role: role, staffId: staffId))!;

List<String> _labels(List<NavItem> items) => [for (final i in items) i.label];

void main() {
  group('manager bar', () {
    test('slot: 5 items with Navbatlar', () {
      final items = managerNavItems(_active());
      expect(_labels(items), ['Bosh sahifa', 'Jadval', 'Navbatlar', 'Mijozlar', "Ko'proq"]);
      expect([for (final i in items) i.branch], [0, 1, 2, 4, 5]);
    });

    test('rental: Ijaralar', () {
      expect(_labels(managerNavItems(_active(engine: Engine.rental))), [
        'Bosh sahifa',
        'Jadval',
        'Ijaralar',
        'Mijozlar',
        "Ko'proq",
      ]);
    });

    test('medical: Qabullar and Buyurtmalar, no Mijozlar', () {
      final labels = _labels(managerNavItems(_active(engine: Engine.medical)));
      expect(labels, ['Bosh sahifa', 'Jadval', 'Qabullar', 'Buyurtmalar', "Ko'proq"]);
      expect(labels, isNot(contains('Mijozlar')));
    });

    test('catalog: 4 items', () {
      final items = managerNavItems(_active(engine: Engine.catalog));
      expect(_labels(items), ['Bosh sahifa', 'Buyurtmalar', 'Mijozlar', "Ko'proq"]);
      expect([for (final i in items) i.branch], [0, 3, 4, 5]);
    });
  });

  group('staff bar', () {
    test('slot', () {
      expect(_labels(staffNavItems(_active(role: BizRole.staff, staffId: 2))), [
        'Mening kunim',
        'Statistikam',
        'Jadvalim',
        'Profil',
      ]);
    });

    test('medical: all five', () {
      final items = staffNavItems(_active(engine: Engine.medical, role: BizRole.staff, staffId: 2));
      expect(_labels(items), ['Mening kunim', 'Statistikam', 'Jadvalim', 'Buyurtmalar', 'Profil']);
      expect([for (final i in items) i.branch], [0, 1, 2, 3, 4]);
    });

    test('catalog: Jadvalim, Buyurtmalar, Profil', () {
      expect(_labels(staffNavItems(_active(engine: Engine.catalog, role: BizRole.staff))), [
        'Jadvalim',
        'Buyurtmalar',
        'Profil',
      ]);
    });
  });

  test("a branch outside the bar highlights Ko'proq", () {
    final items = managerNavItems(_active(engine: Engine.medical));
    expect(selectedNavIndex(items, ManagerBranch.clients, fallbackBranch: ManagerBranch.more), 4);
    expect(selectedNavIndex(items, ManagerBranch.orders, fallbackBranch: ManagerBranch.more), 3);
  });
}
