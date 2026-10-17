/// Mirror of common/rbac/Permissions.php.
abstract final class Permissions {
  static const appointmentsAll = 'appointments.all';
  static const appointmentsManage = 'appointments.manage';
  static const orders = 'orders';
  static const clients = 'clients';
  static const analytics = 'analytics';
  static const finance = 'finance';
  static const payroll = 'payroll';
  static const loyalty = 'loyalty';
  static const inventory = 'inventory';
  static const catalogManage = 'catalog.manage';
  static const teamRead = 'team.read';
  static const teamManage = 'team.manage';
  static const settingsManage = 'settings.manage';
  static const reviews = 'reviews';
  static const uploads = 'uploads';
  static const me = 'me';

  static const List<String> all = [
    appointmentsAll, appointmentsManage, orders, clients, analytics, //
    finance, payroll, loyalty, inventory, catalogManage, teamRead, teamManage, settingsManage,
    reviews, uploads, me,
  ];

  static const List<String> _staff = [orders, me];

  /// business_owner => all; business_admin => all minus team.manage; staff => [orders, me];
  /// other/null => []. (staff = exactly the staff shell: orders board + /v1/me/*; BP §2b/§2.9)
  static List<String> forRole(String? role) {
    switch (role) {
      case 'business_owner':
        return all;
      case 'business_admin':
        return [for (final p in all) if (p != teamManage) p];
      case 'staff':
        return _staff;
    }
    return const <String>[];
  }
}
