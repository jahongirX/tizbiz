/// Every route path of Bizcat (BIZCAT-SPEC §5). Build locations only with these helpers.
abstract final class AppRoutes {
  static const splash = '/splash', onboarding = '/onboarding', city = '/city';
  static const login = '/login', loginCode = '/login/code', loginName = '/login/name';
  static const home = '/home', explore = '/explore', bookings = '/bookings', favorites = '/favorites', profile = '/profile';
  static const profileEdit = '/profile/edit', wallet = '/profile/wallet', myReviews = '/profile/reviews';
  static const reviewNewPath = '/review/new';

  /// '/login?from=%2Fb%2Fx%2Fbook&expired=1'.
  static String loginWith({String? from, bool expired = false}) =>
      _build(login, {'from': from, 'expired': expired ? '1' : null});

  /// '/login/code?phone=%2B998900000001&from=...'.
  static String loginCodeWith({required String phone, String? from}) =>
      _build(loginCode, {'phone': phone, 'from': from});

  static String loginNameWith({String? from}) => _build(loginName, {'from': from});

  static String onboardingWith({String? from}) => _build(onboarding, {'from': from});

  static String exploreWith({String? q, String? category, String? sort, bool focus = false}) =>
      _build(explore, {'q': q, 'category': category, 'sort': sort, 'focus': focus ? '1' : null});

  /// 'orders' for the orders tab.
  static String bookingsWith({String tab = 'appointments'}) =>
      _build(bookings, {'tab': tab == 'appointments' ? null : tab});

  static String business(String slug, {String? tab}) => _build('/b/${_seg(slug)}', {'tab': tab});
  static String businessReviews(String slug) => '/b/${_seg(slug)}/reviews';
  static String bookSlot(String slug, {int? serviceId, int? staffId}) =>
      _build('/b/${_seg(slug)}/book', {'service': serviceId?.toString(), 'staff': staffId?.toString()});
  static String bookRental(String slug) => '/b/${_seg(slug)}/rent';
  static String menu(String slug, {int? reorder}) => _build('/b/${_seg(slug)}/menu', {'reorder': reorder?.toString()});
  static String cart(String slug) => '/b/${_seg(slug)}/cart';
  static String checkout(String slug) => '/b/${_seg(slug)}/checkout';

  /// '/bookings/a/5012?new=1'.
  static String appointment(int id, {bool created = false}) =>
      _build('/bookings/a/$id', {'new': created ? '1' : null});
  static String order(int id, {bool created = false}) => _build('/bookings/o/$id', {'new': created ? '1' : null});

  /// '/review/new?appointment=4990&bname=Shox+Barber'.
  static String reviewNew({int? appointmentId, int? orderId, String? businessName}) => _build(reviewNewPath, {
        'appointment': appointmentId?.toString(),
        'order': orderId?.toString(),
        'bname': businessName,
      });
  static String reviewEdit(int id) => '/review/$id/edit';

  static String _seg(String s) => Uri.encodeComponent(s);

  static String _build(String path, Map<String, String?> query) {
    final q = <String, String>{
      for (final e in query.entries)
        if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!,
    };
    if (q.isEmpty) return path;
    return Uri(path: path, queryParameters: q).toString();
  }
}

final List<RegExp> _requiredPatterns = [
  RegExp(r'^/login/name$'),
  RegExp(r'^/bookings/[ao]/\d+$'),
  RegExp(r'^/profile/(edit|wallet|reviews)$'),
  RegExp(r'^/b/[^/]+/(book|rent|checkout)$'),
  RegExp(r'^/review/(new|\d+/edit)$'),
];

/// true for rows marked "required" in BIZCAT-SPEC §5.1 (tested in test/app/router_test.dart).
bool routeRequiresAuth(Uri uri) {
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) path = path.substring(0, path.length - 1);
  return _requiredPatterns.any((p) => p.hasMatch(path));
}

/// A `from` value that is safe to navigate to after splash/login: it starts with '/', and not
/// with '/splash' or '/login'. Anything else -> null.
String? safeFrom(String? from) {
  if (from == null) return null;
  final f = from.trim();
  if (f.isEmpty || !f.startsWith('/') || f.startsWith('//')) return null;
  if (f.startsWith(AppRoutes.splash) || f.startsWith(AppRoutes.login)) return null;
  return f;
}
