// End-to-end contract smoke test: drives a REAL API (local `php -S` or prod)
// through tizbiz_core exactly like the apps do, and checks that every
// response the apps rely on decodes into the shared models.
//
//   E2E_BASE=http://127.0.0.1:8899 dart run tool/e2e_smoke.dart
//
// Read-only except for an idempotent favorite toggle (restored afterwards).
import 'dart:io';

import 'package:tizbiz_core/tizbiz_core.dart';

final _results = <String>[];
var _fail = 0;

void _ok(String name, [String note = '']) => _results.add('PASS  $name${note.isEmpty ? '' : '  ($note)'}');
void _bad(String name, Object why) {
  _fail++;
  _results.add('FAIL  $name  -> $why');
}

Map<String, dynamic> _map(Object? d) => (d is Map) ? d.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? d) =>
    (d is List) ? d.whereType<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList() : const [];

/// Calls [path], decodes with [model], then runs [check] on the raw JSON.
Future<Object?> _check(
  ApiClient api,
  String name,
  String path, {
  Map<String, Object?>? query,
  Object? Function(Map<String, dynamic>)? model,
  bool list = false,
  String? Function(Object? raw)? check,
}) async {
  try {
    final raw = await api.get<Object?>(path, query: query);
    if (model != null) {
      if (list) {
        for (final row in _list(raw)) {
          model(row);
        }
      } else {
        model(_map(raw));
      }
    }
    final problem = check?.call(raw);
    if (problem != null) {
      _bad(name, problem);
    } else {
      _ok(name, list ? '${_list(raw).length} rows' : '');
    }
    return raw;
  } on ApiException catch (e) {
    _bad(name, 'HTTP ${e.status} ${e.detail}');
  } catch (e) {
    _bad(name, e);
  }
  return null;
}

/// Expects the call to fail with [status].
Future<void> _deny(ApiClient api, String name, String path, int status) async {
  try {
    await api.get<Object?>(path);
    _bad(name, 'expected $status, got 2xx');
  } on ApiException catch (e) {
    e.status == status ? _ok(name, '$status') : _bad(name, 'expected $status, got ${e.status}');
  } catch (e) {
    _bad(name, e);
  }
}

String _today() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

Future<void> main() async {
  final base = Platform.environment['E2E_BASE'] ?? 'http://127.0.0.1:8899';
  final config = ApiConfig(baseUrl: base);
  stdout.writeln('E2E against $base');

  // ---------------- Owner (business app, manager shell) ----------------
  final owner = ApiClient(config: config, tokenKind: TokenKind.biz);
  try {
    final raw = await owner.post<Object?>(Endpoints.login,
        body: {'phone': '+998901111111', 'password': 'secret123'}, auth: RequestAuth.none);
    final s = AuthSession.fromJson(_map(raw));
    await owner.setToken(s.token);
    final active = _map(_map(raw)['active']);
    active['business_id'] == null ? _bad('owner login', 'no active business') : _ok('owner login', 'role ${active['role']}');
  } catch (e) {
    _bad('owner login', e);
  }
  final today = _today();
  await _check(owner, 'owner auth/me', Endpoints.authMe, model: AuthMe.fromJson);
  await _check(owner, 'owner appointments today', Endpoints.appointments,
      query: {'from': '$today 00:00:00', 'to': '$today 23:59:59'}, model: Appointment.fromJson, list: true);
  await _check(owner, 'owner orders', Endpoints.orders, model: Order.fromJson, list: true);
  await _check(owner, 'owner clients page', Endpoints.clients, query: {'page': 1, 'per_page': 5}, model: Client.fromJson, list: true);
  await _check(owner, 'owner services', Endpoints.services, model: Service.fromJson, list: true);
  await _check(owner, 'owner service categories', Endpoints.serviceCategories, model: ServiceCategory.fromJson, list: true);
  final staffRaw = await _check(owner, 'owner staff', Endpoints.staff, model: Staff.fromJson, list: true);
  final firstStaff = _list(staffRaw).isEmpty ? null : _list(staffRaw).first['id'];
  if (firstStaff is int) {
    await _check(owner, 'owner working hours', Endpoints.workingHours(firstStaff), model: WorkingHours.fromJson, list: true);
  }
  final monthAgo = DateTime.now().subtract(const Duration(days: 30));
  final from = '${monthAgo.year}-${monthAgo.month.toString().padLeft(2, '0')}-${monthAgo.day.toString().padLeft(2, '0')}';
  await _check(owner, 'owner analytics overview', Endpoints.analyticsOverview,
      query: {'from': from, 'to': today}, model: AnalyticsOverview.fromJson);
  await _check(owner, 'owner finance summary', Endpoints.financeSummary,
      query: {'from': from, 'to': today}, model: FinanceSummary.fromJson);
  await _check(owner, 'owner payroll', Endpoints.payroll, query: {'from': from, 'to': today}, model: PayrollReport.fromJson);
  await _check(owner, 'owner reviews', Endpoints.reviews, model: Review.fromJson, list: true);
  await _check(owner, 'owner booking settings', Endpoints.bookingSettings, model: BookingSettings.fromJson);
  await _check(owner, 'owner team', Endpoints.team, model: TeamMember.fromJson, list: true);

  // ---------------- Staff (business app, staff shell) ----------------
  final staff = ApiClient(config: config, tokenKind: TokenKind.biz);
  try {
    final raw = await staff.post<Object?>(Endpoints.login,
        body: {'phone': '+998931110001', 'password': 'secret123'}, auth: RequestAuth.none);
    await staff.setToken(AuthSession.fromJson(_map(raw)).token);
    final active = _map(_map(raw)['active']);
    active['staff_id'] == null ? _bad('staff login', 'staff_id not linked') : _ok('staff login', 'staff_id ${active['staff_id']}');
  } catch (e) {
    _bad('staff login', e);
  }
  await _check(staff, 'staff me/staff', Endpoints.meStaff, model: Staff.fromJson);
  await _check(staff, 'staff me/appointments', Endpoints.meAppointments,
      query: {'from': today, 'to': today}, model: Appointment.fromJson, list: true);
  await _check(staff, 'staff me/stats', Endpoints.meStats, query: {'from': from, 'to': today}, model: MeStats.fromJson);
  await _check(staff, 'staff me/schedule', Endpoints.meSchedule, model: MeSchedule.fromJson);
  await _deny(staff, 'staff denied payroll', Endpoints.payroll, 403);
  await _deny(staff, 'staff denied clients', Endpoints.clients, 403);
  await _deny(staff, 'staff denied analytics', Endpoints.analyticsOverview, 403);

  // ---------------- Consumer (Bizcat) ----------------
  final consumer = ApiClient(config: config, tokenKind: TokenKind.consumer);
  try {
    await consumer.post<Object?>(Endpoints.consumerOtp, body: {'phone': '+998900000001'}, auth: RequestAuth.none);
    final raw = await consumer.post<Object?>(Endpoints.consumerVerify,
        body: {'phone': '+998900000001', 'code': '1111'}, auth: RequestAuth.none);
    await consumer.setToken(ConsumerSession.fromJson(_map(raw)).token);
    _ok('consumer OTP login');
  } catch (e) {
    _bad('consumer OTP login', e);
  }
  await _check(consumer, 'directory categories', Endpoints.directoryCategories, model: Category.fromJson, list: true,
      check: (r) => _list(r).isEmpty ? 'no categories' : null);
  final dir = await _check(consumer, 'directory businesses', Endpoints.directoryBusinesses,
      query: {'sort': 'rating', 'per_page': 20}, model: BusinessCard.fromJson, list: true, check: (r) {
    for (final b in _list(r)) {
      for (final leak in ['telegram_bot_token', 'features', 'tariff', 'commission_percent']) {
        if (b.containsKey(leak)) return 'leaks $leak';
      }
    }
    return _list(r).isEmpty ? 'empty directory' : null;
  });
  for (final b in _list(dir)) {
    final slug = b['slug'] as String?;
    if (slug == null) continue;
    await _check(consumer, 'detail $slug', Endpoints.directoryBusiness(slug), model: BusinessPage.fromJson);
    await _check(consumer, 'reviews $slug', Endpoints.directoryReviews(slug), model: Review.fromJson, list: true);
    await _check(consumer, 'storefront $slug', Endpoints.site(slug), model: StorefrontData.fromJson, check: (r) {
      for (final s in _list(_map(r)['staff'])) {
        if (s.containsKey('commission_percent') || s.containsKey('user_id')) return 'staff leak';
      }
      return null;
    });
  }
  await _check(consumer, 'consumer me', Endpoints.consumerMe, model: ConsumerUser.fromJson);
  await _check(consumer, 'consumer favorites', Endpoints.consumerFavorites, model: BusinessCard.fromJson, list: true);
  await _check(consumer, 'consumer appointments upcoming', Endpoints.consumerAppointments,
      query: {'scope': 'upcoming'}, model: Appointment.fromJson, list: true);
  await _check(consumer, 'consumer appointments past', Endpoints.consumerAppointments,
      query: {'scope': 'past'}, model: Appointment.fromJson, list: true);
  await _check(consumer, 'consumer orders', Endpoints.consumerOrders, model: Order.fromJson, list: true);
  await _check(consumer, 'consumer loyalty', Endpoints.consumerLoyalty, model: LoyaltyWalletEntry.fromJson, list: true);
  await _check(consumer, 'consumer reviews', Endpoints.consumerReviews, model: Review.fromJson, list: true);

  // Token separation: a consumer token must never act as a business user.
  // (ApiClient itself refuses a consumer token in a biz client, so send it from the consumer client.)
  await _deny(consumer, 'consumer token on /appointments', Endpoints.appointments, 401);
  await _deny(consumer, 'consumer token on /payroll', Endpoints.payroll, 401);

  stdout.writeln(_results.join('\n'));
  stdout.writeln('\n${_results.length - _fail}/${_results.length} passed');
  exit(_fail == 0 ? 0 : 1);
}
