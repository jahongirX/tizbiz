// Fixture builders: raw JSON (`j*`, copied from BACKEND-PLAN §4 / CORE fixtures) and the core
// models decoded from it (`fx*`). Feed `j*` maps to FakeHttp (`envelope(j...)`), use `fx*` to
// override providers directly.
import 'package:tizbiz_biznes/core/session/session_notifier.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import 'fake_http.dart';

Map<String, dynamic> _m(Map<String, Object?> m) => Map<String, dynamic>.from(m);

// ------------------------------------------------------------------ businesses / session

/// Demo business per engine: (id, name, slug, category).
({int id, String name, String slug, String category}) demoBusiness(Engine engine) => switch (engine) {
      Engine.slot => (id: 2, name: 'Shox Barber', slug: 'shox-barber', category: 'barber'),
      Engine.catalog => (id: 3, name: 'Aziza Tortlari', slug: 'aziza-tortlari', category: 'cafe'),
      Engine.medical => (id: 4, name: 'Sanatrix', slug: 'sanatrix', category: 'clinic'),
      Engine.rental => (id: 5, name: 'Serenada', slug: 'serenada', category: 'rental'),
    };

Map<String, dynamic> jMembership({
  int id = 2,
  String name = 'Shox Barber',
  String slug = 'shox-barber',
  String? category = 'barber',
  Engine engine = Engine.slot,
  BizRole role = BizRole.owner,
  String? logo,
}) =>
    _m({'id': id, 'name': name, 'slug': slug, 'category': category, 'engine': engine.wire, 'logo': logo, 'role': role.wire});

BusinessMembership fxMembership({Engine engine = Engine.slot, BizRole role = BizRole.owner, String? category}) {
  final b = demoBusiness(engine);
  return BusinessMembership.fromJson(
    jMembership(id: b.id, name: b.name, slug: b.slug, category: category ?? b.category, engine: engine, role: role),
  );
}

Map<String, dynamic> jUser({int id = 4, String phone = '+998901111111', String name = 'Shoxrux Karimov'}) =>
    _m({'id': id, 'phone': phone, 'name': name, 'status': 10, 'is_superadmin': false, 'created_at': 1784364000, 'updated_at': 1792213920});

/// `active` of login/me/switch. [permissions] null -> Permissions.forRole(role).
Map<String, dynamic> jActive({int? businessId = 2, BizRole? role = BizRole.owner, int? staffId, List<String>? permissions}) =>
    _m({
      'business_id': businessId,
      'role': role?.wire,
      'staff_id': staffId,
      'permissions': permissions ?? Permissions.forRole(role?.wire),
    });

/// `/v1/auth/me` data.
Map<String, dynamic> jAuthMe({
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<Map<String, dynamic>>? businesses,
  int? activeBusinessId,
  List<String>? permissions,
  Map<String, dynamic>? user,
}) {
  final b = demoBusiness(engine);
  return _m({
    'user': user ?? (role == BizRole.staff ? jUser(id: 31, phone: '+998931110001', name: 'Usta Jahongir') : jUser()),
    'active': jActive(businessId: activeBusinessId ?? b.id, role: role, staffId: staffId, permissions: permissions),
    'businesses': businesses ??
        [jMembership(id: b.id, name: b.name, slug: b.slug, category: category ?? b.category, engine: engine, role: role)],
  });
}

/// `/v1/auth/login` data (token + expires_at + me).
Map<String, dynamic> jLogin({
  String? token,
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<Map<String, dynamic>>? businesses,
  int? activeBusinessId,
}) {
  final t = token ?? fakeBizToken(sub: role == BizRole.staff ? 31 : 4, tid: demoBusiness(engine).id, role: role.wire);
  return _m({
    'token': t,
    'expires_at': JwtClaims.tryParse(t)?.expiresAt == null ? null : Dates.toUnix(JwtClaims.tryParse(t)!.expiresAt!),
    ...jAuthMe(
      role: role,
      engine: engine,
      staffId: staffId,
      category: category,
      businesses: businesses,
      activeBusinessId: activeBusinessId,
    ),
  });
}

/// A signed-in [AuthSession]. [businesses] replaces the single demo membership.
AuthSession fxAuthSession({
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<BusinessMembership>? businesses,
  int? activeBusinessId,
  List<String>? permissions,
}) {
  final json = jLogin(role: role, engine: engine, staffId: staffId, category: category);
  final session = AuthSession.fromJson(json);
  final active = permissions == null && activeBusinessId == null
      ? session.active
      : ActiveContext(
          businessId: activeBusinessId ?? session.active.businessId,
          role: session.active.role,
          staffId: session.active.staffId,
          permissions: permissions ?? session.active.permissions,
        );
  return AuthSession(
    token: session.token,
    expiresAt: session.expiresAt,
    user: session.user,
    businesses: businesses ?? session.businesses,
    active: active,
  );
}

/// `SessionSignedIn(epoch: 1)` around [fxAuthSession].
SessionSignedIn fxSignedIn({
  BizRole role = BizRole.owner,
  Engine engine = Engine.slot,
  int? staffId,
  String? category,
  List<BusinessMembership>? businesses,
  int? activeBusinessId,
  List<String>? permissions,
  bool needsPicker = false,
  bool fromCache = false,
  int epoch = 1,
}) =>
    SessionSignedIn(
      session: fxAuthSession(
        role: role,
        engine: engine,
        staffId: staffId,
        category: category,
        businesses: businesses,
        activeBusinessId: activeBusinessId,
        permissions: permissions,
      ),
      epoch: epoch,
      needsPicker: needsPicker,
      fromCache: fromCache,
    );

// ------------------------------------------------------------------ appointments / orders

Map<String, dynamic> jAppointment({
  int id = 5012,
  AppointmentStatus status = AppointmentStatus.confirmed,
  String startsAt = '2026-10-17 05:00:00',
  String endsAt = '2026-10-17 05:40:00',
  int staffId = 2,
  int serviceId = 11,
  int? clientId = 881,
  int? guests,
  int? depositTiyin = 2000000,
  bool paid = true,
  String source = 'app',
  String? notes,
  String clientName = 'Aziza Karimova',
  String clientPhone = '+998900000001',
  String serviceName = 'Soch olish + soqol',
  int serviceDuration = 40,
  String staffName = 'Usta Jahongir',
  List<Map<String, Object?>> items = const [],
}) =>
    _m({
      'id': id, 'business_id': 2, 'client_id': clientId, 'consumer_id': 17, 'staff_id': staffId,
      'service_id': serviceId, 'guests': guests, 'starts_at': startsAt, 'ends_at': endsAt,
      'status': status.wire, 'source': source, 'deposit_tiyin': depositTiyin, 'paid': paid, 'notes': notes,
      'created_at': 1792054800, 'updated_at': 1792054800, 'client_name': clientName,
      'client_phone': clientPhone, 'service_name': serviceName, 'service_duration': serviceDuration,
      'staff_name': staffName, 'items': items,
    });

Appointment fxAppointment({
  int id = 5012,
  AppointmentStatus status = AppointmentStatus.confirmed,
  String startsAt = '2026-10-17 05:00:00',
  String endsAt = '2026-10-17 05:40:00',
  int staffId = 2,
  int serviceId = 11,
  int? clientId = 881,
  int? guests,
  int? depositTiyin = 2000000,
  bool paid = true,
  String clientName = 'Aziza Karimova',
  String serviceName = 'Soch olish + soqol',
  String staffName = 'Usta Jahongir',
}) =>
    Appointment.fromJson(jAppointment(
      id: id,
      status: status,
      startsAt: startsAt,
      endsAt: endsAt,
      staffId: staffId,
      serviceId: serviceId,
      clientId: clientId,
      guests: guests,
      depositTiyin: depositTiyin,
      paid: paid,
      clientName: clientName,
      serviceName: serviceName,
      staffName: staffName,
    ));

Map<String, dynamic> jOrder({
  int id = 690,
  OrderStatus status = OrderStatus.newOrder,
  int totalTiyin = 22500000,
  String customerName = 'Aziza Karimova',
  String customerPhone = '+998900000001',
  String? note,
  String source = 'site',
  int createdAt = 1792054800,
  List<Map<String, Object?>>? items,
}) {
  final lines = items ??
      [
        {'id': 1490, 'service_id': 61, 'name': 'Napoleon torti (1 kg)', 'price_tiyin': totalTiyin, 'qty': 1},
      ];
  return _m({
    'id': id, 'status': status.wire, 'total_tiyin': totalTiyin, 'customer_name': customerName,
    'customer_phone': customerPhone, 'note': note, 'source': source, 'created_at': createdAt,
    'items': lines, 'items_count': lines.length,
  });
}

Order fxOrder({int id = 690, OrderStatus status = OrderStatus.newOrder, int totalTiyin = 22500000, String customerName = 'Aziza Karimova'}) =>
    Order.fromJson(jOrder(id: id, status: status, totalTiyin: totalTiyin, customerName: customerName));

// ------------------------------------------------------------------ clients

Map<String, dynamic> jClient({int id = 881, String name = 'Aziza Karimova', String phone = '+998900000001', int visits = 5, int spentTiyin = 40000000}) =>
    _m({
      'id': id, 'name': name, 'phone': phone, 'email': null, 'birthday': '1996-04-12', 'tags': ['vip'],
      'created_at': 1784364000, 'visits': visits, 'spent_tiyin': spentTiyin, 'last_visit': '2026-10-01 06:00:00',
      'categories': [
        {'id': 1, 'name': 'VIP', 'color': '#F59E0B'},
      ],
    });

Client fxClient({int id = 881, String name = 'Aziza Karimova', String phone = '+998900000001'}) =>
    Client.fromJson(jClient(id: id, name: name, phone: phone));

Map<String, dynamic> jClientDetail({int id = 881}) => _m({
      'client': {
        'id': id, 'business_id': 2, 'name': 'Aziza Karimova', 'phone': '+998900000001', 'email': null,
        'birthday': '1996-04-12', 'notes': 'Soqolni qisqa yoqtiradi', 'tags': ['vip'], 'created_at': 1784364000,
        'updated_at': 1792213920,
      },
      'categories': [
        {'id': 1, 'name': 'VIP', 'color': '#F59E0B'},
      ],
      'history': [jAppointment(id: 4990, status: AppointmentStatus.completed, startsAt: '2026-10-01 06:00:00', endsAt: '2026-10-01 06:40:00', source: 'link')],
      'loyalty': {'points': 120, 'cashback_tiyin': 1500000},
    });

ClientDetail fxClientDetail({int id = 881}) => ClientDetail.fromJson(jClientDetail(id: id));

Map<String, dynamic> jClientCategory({int id = 1, String name = 'VIP', String color = '#F59E0B', int sort = 1}) =>
    _m({'id': id, 'business_id': 2, 'name': name, 'color': color, 'sort': sort});

// ------------------------------------------------------------------ catalog / staff / schedule

Map<String, dynamic> jService({
  int id = 11,
  String name = 'Soch olish + soqol',
  int? categoryId = 5,
  int durationMin = 40,
  int priceTiyin = 8000000,
  int? depositTiyin = 1000000,
  bool isActive = true,
  bool onlineBookable = true,
}) =>
    _m({
      'id': id, 'business_id': 2, 'category_id': categoryId, 'name': name, 'duration_min': durationMin,
      'price_tiyin': priceTiyin, 'deposit_tiyin': depositTiyin, 'is_active': isActive ? 1 : 0,
      'online_bookable': onlineBookable ? 1 : 0, 'image': null, 'description': null, 'gallery': null,
      'created_at': 1784364000, 'updated_at': 1784364000,
    });

Service fxService({int id = 11, String name = 'Soch olish + soqol', int? categoryId = 5, int priceTiyin = 8000000, bool isActive = true}) =>
    Service.fromJson(jService(id: id, name: name, categoryId: categoryId, priceTiyin: priceTiyin, isActive: isActive));

Map<String, dynamic> jCategory({int id = 5, String name = 'Soch', int sort = 1}) =>
    _m({'id': id, 'business_id': 2, 'name': name, 'sort': sort, 'image': null});

ServiceCategory fxCategory({int id = 5, String name = 'Soch', int sort = 1}) =>
    ServiceCategory.fromJson(jCategory(id: id, name: name, sort: sort));

Map<String, dynamic> jStaff({
  int id = 2,
  String name = 'Usta Jahongir',
  String? specialization = 'Sartarosh',
  int? userId = 31,
  int commissionPercent = 40,
  bool isActive = true,
}) =>
    _m({
      'id': id, 'business_id': 2, 'user_id': userId, 'name': name, 'specialization': specialization,
      'is_active': isActive ? 1 : 0, 'created_at': 1784364000, 'updated_at': 1792213920,
      'commission_percent': commissionPercent,
    });

Staff fxStaff({int id = 2, String name = 'Usta Jahongir', String? specialization = 'Sartarosh', int? userId = 31, bool isActive = true}) =>
    Staff.fromJson(jStaff(id: id, name: name, specialization: specialization, userId: userId, isActive: isActive));

Map<String, dynamic> jWorkingHours({int id = 21, int staffId = 2, int weekday = 1, String start = '09:00:00', String end = '20:00:00'}) =>
    _m({'id': id, 'staff_id': staffId, 'weekday': weekday, 'start_time': start, 'end_time': end});

WorkingHours fxWorkingHours({int id = 21, int staffId = 2, int weekday = 1, String start = '09:00:00', String end = '20:00:00'}) =>
    WorkingHours.fromJson(jWorkingHours(id: id, staffId: staffId, weekday: weekday, start: start, end: end));

Map<String, dynamic> jTimeOff({int id = 4, int staffId = 2, String date = '2026-10-25', String? start, String? end, String? reason = 'Dam olish'}) =>
    _m({'id': id, 'staff_id': staffId, 'date': date, 'start_time': start, 'end_time': end, 'reason': reason});

TimeOff fxTimeOff({int id = 4, int staffId = 2, String date = '2026-10-25', String? start, String? end, String? reason = 'Dam olish'}) =>
    TimeOff.fromJson(jTimeOff(id: id, staffId: staffId, date: date, start: start, end: end, reason: reason));

// ------------------------------------------------------------------ reports

Map<String, dynamic> jAnalytics() => _m({
      'revenue_tiyin': 48000000,
      'appointments': {'total': 8, 'completed': 6, 'no_show': 0, 'canceled': 1, 'pending': 0, 'confirmed': 1, 'arrived': 0},
      'no_show_rate': 0,
      'clients': {'total': 120, 'new': 4},
      'series': [
        {'date': '2026-10-15', 'revenue_tiyin': 0, 'appointments': 0},
        {'date': '2026-10-16', 'revenue_tiyin': 24000000, 'appointments': 4},
        {'date': '2026-10-17', 'revenue_tiyin': 24000000, 'appointments': 4},
      ],
      'top_services': [
        {'service_id': 11, 'name': 'Soch olish + soqol', 'count': 6, 'revenue_tiyin': 48000000},
      ],
      'staff_load': [
        {'staff_id': 2, 'name': 'Usta Jahongir', 'count': 8, 'revenue_tiyin': 48000000},
      ],
    });

AnalyticsOverview fxAnalytics() => AnalyticsOverview.fromJson(jAnalytics());

Map<String, dynamic> jPayroll() => _m({
      'staff': [
        {'staff_id': 2, 'name': 'Usta Jahongir', 'commission_percent': 40, 'appointments': 6, 'revenue_tiyin': 48000000, 'earnings_tiyin': 19200000},
      ],
      'totals': {'revenue_tiyin': 48000000, 'earnings_tiyin': 19200000},
    });

PayrollReport fxPayroll() => PayrollReport.fromJson(jPayroll());

Map<String, dynamic> jFinanceSummary() => _m({
      'from': '2026-09-18', 'to': '2026-10-17', 'income_tiyin': 6000000, 'refunds_tiyin': 0, 'net_tiyin': 6000000,
      'count': 3,
      'by_provider': [
        {'provider': 'payme', 'amount_tiyin': 6000000, 'count': 3},
      ],
    });

FinanceSummary fxFinanceSummary() => FinanceSummary.fromJson(jFinanceSummary());

Map<String, dynamic> jTransaction({int id = 301}) => _m({
      'id': id, 'provider': 'payme', 'type': 'deposit', 'status': 'paid', 'amount_tiyin': 2000000,
      'created_at': 1792213920, 'appointment_id': 5012, 'client_name': 'Aziza Karimova',
      'service_name': 'Soch olish + soqol',
    });

Paged<FinanceTransaction> fxTransactions({int count = 1}) => Paged(
      items: [for (var i = 0; i < count; i++) FinanceTransaction.fromJson(jTransaction(id: 301 + i))],
      meta: PageMeta(page: 1, perPage: 20, total: count, pages: 1),
    );

Map<String, dynamic> jReview({int id = 88, int rating = 5, String? reply, String status = 'published'}) => _m({
      'id': id, 'rating': rating, 'comment': "Usta juda e'tiborli!", 'author_name': 'Aziza K.', 'status': status,
      'appointment_id': 4990, 'order_id': null, 'staff_id': 2, 'staff_name': 'Usta Jahongir', 'service_id': 11,
      'service_name': 'Soch olish', 'reply': reply, 'replied_at': reply == null ? null : 1791636000,
      'created_at': 1791500000,
    });

Review fxReview({int id = 88, int rating = 5, String? reply}) => Review.fromJson(jReview(id: id, rating: rating, reply: reply));

Map<String, dynamic> jRatingMeta() => _m({
      'page': 1, 'per_page': 20, 'total': 15, 'pages': 1, 'avg': 4.73, 'count': 15,
      'distribution': {'1': 0, '2': 0, '3': 1, '4': 2, '5': 12},
    });

RatingSummary fxRatingSummary() => RatingSummary.fromMeta(PageMeta.fromJson(jRatingMeta()));

Map<String, dynamic> jSettings() => _m({
      'name': 'Shox Barber', 'phone': '+998901111111', 'tagline': 'Chilonzordagi eng yaxshi soch turmaklari',
      'slug': 'shox-barber', 'online_booking_enabled': true, 'booking_lead_min': 60, 'booking_horizon_days': 30,
      'logo': null, 'cover': null, 'brand_color': '#1E1B4B', 'brand_color_2': null, 'telegram_connected': true,
      'telegram_bot_username': 'shoxbarber_bot', 'address': 'Chilonzor 9-kvartal, 12-uy',
      'map_url': 'https://yandex.uz/maps/-/CDabc', 'city': 'Toshkent', 'district': 'Chilonzor', 'lat': 41.2756,
      'lng': 69.2034, 'description': 'Erkaklar uchun zamonaviy barbershop.', 'is_listed': true, 'rating_avg': 4.73,
      'rating_count': 15,
    });

BookingSettings fxSettings() => BookingSettings.fromJson(jSettings());

List<Map<String, dynamic>> jTeam() => [
      _m({'user_id': 4, 'name': 'Shoxrux Karimov', 'phone': '+998901111111', 'role': 'business_owner', 'staff_id': null}),
      _m({'user_id': 31, 'name': 'Usta Jahongir', 'phone': '+998931110001', 'role': 'staff', 'staff_id': 2}),
    ];

List<TeamMember> fxTeam() => [for (final j in jTeam()) TeamMember.fromJson(j)];

// ------------------------------------------------------------------ staff self-service (/v1/me/*)

Map<String, dynamic> jMeStats() => _m({
      'range': {'from': '2026-10-01', 'to': '2026-10-17', 'timezone': 'Asia/Tashkent'},
      'staff': {'id': 2, 'name': 'Usta Jahongir', 'commission_percent': 40},
      'appointments': {'total': 64, 'pending': 2, 'confirmed': 3, 'arrived': 0, 'completed': 52, 'no_show': 4, 'canceled': 3},
      'revenue_tiyin': 416000000,
      'earnings_tiyin': 166400000,
      'clients_served': 41,
      'series': [
        {'date': '2026-10-01', 'count': 4, 'completed': 3, 'revenue_tiyin': 24000000, 'earnings_tiyin': 9600000},
      ],
      'today': {'total': 6, 'completed': 2, 'next_at': '2026-10-17 09:30:00'},
    });

MeStats fxMeStats() => MeStats.fromJson(jMeStats());

Map<String, dynamic> jMeSchedule() => _m({
      'working_hours': [
        {'id': 21, 'weekday': 1, 'start_time': '09:00:00', 'end_time': '20:00:00'},
      ],
      'time_off': [
        {'id': 4, 'date': '2026-10-25', 'start_time': null, 'end_time': null, 'reason': 'Dam olish'},
      ],
    });

MeSchedule fxMeSchedule() => MeSchedule.fromJson(jMeSchedule());

Map<String, dynamic> jMeStaff() => _m({
      'id': 2, 'business_id': 2, 'name': 'Usta Jahongir', 'specialization': 'Sartarosh', 'commission_percent': 40,
      'is_active': true,
      'business': {'id': 2, 'name': 'Shox Barber', 'slug': 'shox-barber', 'engine': 'slot', 'timezone': 'Asia/Tashkent', 'logo': null},
    });

Staff fxMeStaff() => Staff.fromJson(jMeStaff());
