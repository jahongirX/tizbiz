// JSON responses copied from docs/mobile/BACKEND-PLAN.md §4 (full envelopes, as the server sends
// them), plus the storefront payloads of BIZCAT-SPEC §13.1. Register them with FakeApi.on(...).
//
// Values are const maps; to build a model use `Fx.data(Fx.me)` / `Fx.items(Fx.cards)`, which
// return JSON-normalised `Map<String, dynamic>` values.

import 'dart:convert';

abstract final class Fx {
  // ---------- helpers ----------

  /// The envelope `data` object as `Map<String, dynamic>` (deep-copied through JSON).
  static Map<String, dynamic> data(Map<String, dynamic> envelope) =>
      (jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  /// The envelope `data` list items as `Map<String, dynamic>` (deep-copied through JSON).
  static List<Map<String, dynamic>> items(Map<String, dynamic> envelope) => [
        for (final e in (jsonDecode(jsonEncode(envelope)) as Map<String, dynamic>)['data'] as List<dynamic>)
          e as Map<String, dynamic>,
      ];

  /// `{"data": <data>}`.
  static Map<String, dynamic> wrap(Object? data) => {'data': data};

  /// A paged envelope: `{"data": [...], "meta": {page, per_page, total, pages}}`.
  static Map<String, dynamic> page(List<Object?> items, {int page = 1, int perPage = 20, int? total, int? pages}) {
    final t = total ?? items.length;
    return {
      'data': items,
      'meta': {
        'page': page,
        'per_page': perPage,
        'total': t,
        'pages': pages ?? (t == 0 ? 0 : (t + perPage - 1) ~/ perPage),
      },
    };
  }

  /// An empty paged list.
  static const Map<String, dynamic> emptyPage = {
    'data': <Object?>[],
    'meta': {'page': 1, 'per_page': 20, 'total': 0, 'pages': 0},
  };

  /// An empty non-paged list.
  static const Map<String, dynamic> emptyList = {'data': <Object?>[]};

  /// An error envelope: `{"errors":[{"status","title","detail","source":{"pointer"}}]}`.
  static Map<String, dynamic> error(int status, String detail, {String? title, String? pointer}) => {
        'errors': [
          {
            'status': '$status',
            'title': title ?? _titles[status] ?? 'Error',
            'detail': detail,
            if (pointer != null) 'source': {'pointer': pointer},
          },
        ],
      };

  static const Map<int, String> _titles = {
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not Found',
    409: 'Conflict',
    422: 'Validation error',
    429: 'Too Many Requests',
    500: 'Internal Server Error',
    503: 'Service Unavailable',
  };

  static const Map<String, dynamic> unauthorized = {
    'errors': [
      {'status': '401', 'title': 'Unauthorized', 'detail': 'Your request was made with invalid credentials.'},
    ],
  };

  // ---------- consumer auth + me (BP 4.6) ----------

  static const Map<String, dynamic> otp = {
    "data": {"sent": true, "ttl_sec": 120, "retry_after_sec": 60},
  };

  static const Map<String, dynamic> consumerJson = {
    "id": 17,
    "phone": "+998900000001",
    "name": "Aziza Karimova",
    "birthday": null,
    "gender": "female",
    "city": "Toshkent",
    "locale": "uz",
    "created_at": 1792195200,
  };

  /// Unsigned consumer JWTs (typ consumer, exp 2100-01-01) for consumers 17 and 19. The client
  /// only decodes tokens, so these are accepted by `ApiClient.setToken`.
  static const String token17 = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ0aXpiaXoudXoiLCJzdWIiOjE3LCJ0eXAiOiJjb25zdW1lciIsImlhdCI6MTc5MjE5NTIwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.c2lnbmF0dXJl';
  static const String token19 = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ0aXpiaXoudXoiLCJzdWIiOjE5LCJ0eXAiOiJjb25zdW1lciIsImlhdCI6MTc5MjE5NTIwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.c2lnbmF0dXJl';

  /// verify (BP shows "eyJ..."; a decodable token is used so signIn() accepts it).
  static const Map<String, dynamic> verify = {
    "data": {"token": token17, "expires_at": 1794805920, "is_new": false, "consumer": consumerJson},
  };

  /// A new account without a name (`is_new: true`).
  static const Map<String, dynamic> verifyNew = {
    "data": {
      "token": token19,
      "expires_at": 1794805920,
      "is_new": true,
      "consumer": {
        "id": 19,
        "phone": "+998900000003",
        "name": null,
        "birthday": null,
        "gender": null,
        "city": null,
        "locale": "uz",
        "created_at": 1792195200,
      },
    },
  };

  static const Map<String, dynamic> me = {
    "data": {
      "id": 17,
      "phone": "+998900000001",
      "name": "Aziza Karimova",
      "birthday": "1996-04-12",
      "gender": "female",
      "city": "Toshkent",
      "locale": "uz",
      "created_at": 1792195200,
      "stats": {
        "appointments_upcoming": 1,
        "appointments_total": 6,
        "orders_total": 2,
        "reviews_total": 3,
        "favorites_total": 2,
      },
    },
  };

  // ---------- directory (BP 4.4) ----------

  /// All 5 category keys, in server order.
  static const Map<String, dynamic> categories = {
    "data": [
      {"key": "barber", "label": "Barber / Go'zallik saloni", "label_ru": "Барбершоп / Салон красоты", "engine": "slot", "icon": "scissors", "count": 1},
      {"key": "cafe", "label": "Kafe / Tortlar", "label_ru": "Кафе / Торты", "engine": "catalog", "icon": "cake", "count": 1},
      {"key": "restaurant", "label": "Restoran", "label_ru": "Ресторан", "engine": "catalog", "icon": "utensils", "count": 1},
      {"key": "clinic", "label": "Klinika / Tibbiyot", "label_ru": "Клиника / Медицина", "engine": "medical", "icon": "stethoscope", "count": 1},
      {"key": "rental", "label": "To'yxona / Ijara", "label_ru": "Тойхона / Прокат", "engine": "rental", "icon": "rings", "count": 1},
    ],
  };

  static const Map<String, dynamic> shoxCard = {
    "id": 2, "slug": "shox-barber", "name": "Shox Barber", "category": "barber", "category_label": "Barber / Go'zallik saloni",
    "engine": "slot", "tagline": "Chilonzordagi eng yaxshi soch turmaklari", "logo": "https://api.tizbiz.uz/uploads/202609/a1b2.png",
    "cover": null, "brand_color": "#1E1B4B", "brand_color_2": null, "address": "Chilonzor 9-kvartal, 12-uy", "city": "Toshkent",
    "district": "Chilonzor", "lat": 41.2756, "lng": 69.2034, "rating_avg": 4.73, "rating_count": 15, "is_featured": false,
    "online_booking_enabled": true, "price_from_tiyin": 5000000, "is_favorite": true,
  };

  static const Map<String, dynamic> azizaCard = {
    "id": 3, "slug": "aziza-tortlari", "name": "Aziza Tortlari", "category": "cafe", "category_label": "Kafe / Tortlar",
    "engine": "catalog", "tagline": "Buyurtma asosida uy tortlari", "logo": null,
    "cover": null, "brand_color": "#F26A35", "brand_color_2": null, "address": "Yunusobod 4-kvartal", "city": "Toshkent",
    "district": "Yunusobod", "lat": 41.3650, "lng": 69.2870, "rating_avg": 4.5, "rating_count": 2, "is_featured": true,
    "online_booking_enabled": true, "price_from_tiyin": 22500000, "is_favorite": false,
  };

  /// GET /v1/directory/businesses: 2 cards (shox-barber, aziza-tortlari).
  static const Map<String, dynamic> cards = {
    "data": [shoxCard, azizaCard],
    "meta": {"page": 1, "per_page": 20, "total": 2, "pages": 1},
  };

  /// GET /v1/consumer/favorites (not paginated).
  static const Map<String, dynamic> favorites = {
    "data": [shoxCard],
  };

  static const Map<String, dynamic> reviewPublic = {
    "id": 88, "rating": 5, "comment": "Usta juda e'tiborli, soch ajoyib chiqdi!", "author_name": "Aziza K.",
    "service_name": "Soch olish", "staff_name": "Usta Jahongir", "reply": "Rahmat, yana kutamiz!",
    "replied_at": 1791636000, "created_at": 1791500000,
  };

  /// GET /v1/directory/businesses/shox-barber.
  static const Map<String, dynamic> detail = {
    "data": {
      "business": {
        "id": 2, "slug": "shox-barber", "name": "Shox Barber", "category": "barber", "category_label": "Barber / Go'zallik saloni",
        "engine": "slot", "tagline": "Chilonzordagi eng yaxshi soch turmaklari", "logo": "https://api.tizbiz.uz/uploads/202609/a1b2.png",
        "cover": null, "brand_color": "#1E1B4B", "brand_color_2": null, "address": "Chilonzor 9-kvartal, 12-uy", "city": "Toshkent",
        "district": "Chilonzor", "lat": 41.2756, "lng": 69.2034, "rating_avg": 4.73, "rating_count": 15, "is_featured": false,
        "online_booking_enabled": true, "price_from_tiyin": 5000000, "is_favorite": false,
        "phone": "+998901111111", "map_url": "https://yandex.uz/maps/-/CDabc",
        "description": "Erkaklar uchun zamonaviy barbershop. 5 nafar tajribali usta.", "timezone": "Asia/Tashkent",
        "telegram_bot_username": "shoxbarber_bot",
        "hours": [
          {"weekday": 1, "open": "09:00", "close": "21:00"},
          {"weekday": 7, "open": "10:00", "close": "18:00"},
        ],
      },
      "rating": {"avg": 4.73, "count": 15, "distribution": {"1": 0, "2": 0, "3": 1, "4": 2, "5": 12}},
      "reviews_preview": [reviewPublic],
      "is_favorite": false,
    },
  };

  /// GET /v1/directory/businesses/shox-barber/reviews.
  static const Map<String, dynamic> reviews = {
    "data": [reviewPublic],
    "meta": {
      "page": 1, "per_page": 20, "total": 15, "pages": 1,
      "avg": 4.73, "count": 15, "distribution": {"1": 0, "2": 0, "3": 1, "4": 2, "5": 12},
    },
  };

  // ---------- consumer appointments (BP 4.6) ----------

  static const Map<String, dynamic> shoxRef = {
    "id": 2, "slug": "shox-barber", "name": "Shox Barber", "logo": null, "brand_color": "#1E1B4B", "phone": "+998901111111",
    "address": "Chilonzor 9-kvartal, 12-uy", "map_url": null, "timezone": "Asia/Tashkent", "engine": "slot",
  };

  /// Upcoming, confirmed, deposit paid.
  static const Map<String, dynamic> appointment5012 = {
    "id": 5012, "status": "confirmed", "starts_at": "2026-10-18 05:00:00", "ends_at": "2026-10-18 05:40:00", "guests": null,
    "deposit_tiyin": 2000000, "paid": true, "notes": null, "source": "app", "created_at": 1792054800,
    "business": shoxRef,
    "staff": {"id": 2, "name": "Usta Jahongir"},
    "service": {"id": 11, "name": "Soch olish + soqol", "duration_min": 40, "price_tiyin": 8000000},
    "can_cancel": false, "can_review": false, "review_id": null,
  };

  /// Past, completed, reviewable.
  static const Map<String, dynamic> appointment4990 = {
    "id": 4990, "status": "completed", "starts_at": "2026-10-01 06:00:00", "ends_at": "2026-10-01 06:40:00", "guests": null,
    "deposit_tiyin": null, "paid": false, "notes": null, "source": "link", "created_at": 1791500000,
    "business": shoxRef,
    "staff": {"id": 2, "name": "Usta Jahongir"},
    "service": {"id": 11, "name": "Soch olish + soqol", "duration_min": 40, "price_tiyin": 8000000},
    "can_cancel": false, "can_review": true, "review_id": null,
  };

  /// Upcoming, pending, deposit NOT paid (Payme button).
  static const Map<String, dynamic> appointmentUnpaid = {
    "id": 5013, "status": "pending", "starts_at": "2026-10-19 04:00:00", "ends_at": "2026-10-19 04:40:00", "guests": null,
    "deposit_tiyin": 2000000, "paid": false, "notes": null, "source": "app", "created_at": 1792213920,
    "business": shoxRef,
    "staff": {"id": 2, "name": "Usta Jahongir"},
    "service": {"id": 11, "name": "Soch olish + soqol", "duration_min": 40, "price_tiyin": 8000000},
    "can_cancel": true, "can_review": false, "review_id": null,
  };

  /// GET /v1/consumer/appointments?scope=upcoming.
  static const Map<String, dynamic> appointmentsUpcoming = {
    "data": [appointment5012],
    "meta": {"page": 1, "per_page": 20, "total": 1, "pages": 1},
  };

  /// GET /v1/consumer/appointments?scope=past.
  static const Map<String, dynamic> appointmentsPast = {
    "data": [appointment4990],
    "meta": {"page": 1, "per_page": 20, "total": 1, "pages": 1},
  };

  // ---------- consumer orders (BP 4.6) ----------

  static const Map<String, dynamic> azizaRef = {
    "id": 3, "slug": "aziza-tortlari", "name": "Aziza Tortlari", "logo": null, "brand_color": "#F26A35", "phone": "+998902222222",
    "address": "Yunusobod 4-kvartal", "map_url": null, "timezone": "Asia/Tashkent", "engine": "catalog",
  };

  static const Map<String, dynamic> order702 = {
    "id": 702, "status": "new", "total_tiyin": 45000000, "customer_name": "Aziza Karimova", "customer_phone": "+998900000001",
    "note": "Tug'ilgan kun uchun yozuv: Lola 7 yosh", "source": "app", "created_at": 1792213920,
    "items": [{"id": 1501, "service_id": 61, "name": "Napoleon torti (1 kg)", "price_tiyin": 22500000, "qty": 2}], "items_count": 1,
    "business": azizaRef,
    "can_cancel": true, "can_review": false, "review_id": null,
  };

  static const Map<String, dynamic> order690 = {
    "id": 690, "status": "delivered", "total_tiyin": 22500000, "customer_name": "Aziza Karimova", "customer_phone": "+998900000001",
    "note": null, "source": "app", "created_at": 1792054800,
    "items": [{"id": 1490, "service_id": 61, "name": "Napoleon torti (1 kg)", "price_tiyin": 22500000, "qty": 1}], "items_count": 1,
    "business": azizaRef,
    "can_cancel": false, "can_review": true, "review_id": null,
  };

  /// GET /v1/consumer/orders?scope=active.
  static const Map<String, dynamic> ordersActive = {
    "data": [order702],
    "meta": {"page": 1, "per_page": 20, "total": 1, "pages": 1},
  };

  /// GET /v1/consumer/orders?scope=past.
  static const Map<String, dynamic> ordersPast = {
    "data": [order690],
    "meta": {"page": 1, "per_page": 20, "total": 1, "pages": 1},
  };

  // ---------- loyalty, reviews, deposit ----------

  static const Map<String, dynamic> loyalty = {
    "data": [
      {
        "business": {"id": 2, "slug": "shox-barber", "name": "Shox Barber", "logo": null, "brand_color": "#1E1B4B"},
        "client_id": 881, "points": 120, "cashback_tiyin": 1500000, "deposit_balance_tiyin": 0, "visits": 5,
      },
    ],
  };

  static const Map<String, dynamic> reviewMine = {
    "id": 88, "rating": 5, "comment": "Usta juda e'tiborli, soch ajoyib chiqdi!", "author_name": "Aziza K.",
    "service_name": "Soch olish", "staff_name": "Usta Jahongir", "reply": null, "replied_at": null, "created_at": 1791500000,
    "business": {"id": 2, "slug": "shox-barber", "name": "Shox Barber", "logo": null},
    "appointment_id": 4990, "order_id": null, "status": "published",
  };

  /// GET /v1/consumer/reviews (not paginated).
  static const Map<String, dynamic> myReviews = {
    "data": [reviewMine],
  };

  /// POST /v1/payments/deposit (201).
  static const Map<String, dynamic> deposit = {
    "data": {
      "transaction": {
        "id": 301, "provider": "payme", "amount_tiyin": 2000000, "type": "deposit", "status": "created",
        "appointment_id": 5012, "created_at": 1792213920, "updated_at": 1792213920,
      },
      "provider": "payme",
      "checkout_url": "https://checkout.paycom.uz/bT0...",
    },
  };

  // ---------- storefronts: GET /v1/site/{slug} ----------

  /// shox-barber, slot: service 11 (40 min, 80 000 so'm, deposit 20 000 so'm), staff 2.
  static const Map<String, dynamic> siteSlot = {
    "data": {
      "engine": "slot",
      "business": {
        "id": 2, "name": "Shox Barber", "slug": "shox-barber", "category": "barber", "phone": "+998901111111",
        "address": "Chilonzor 9-kvartal, 12-uy", "map_url": null, "timezone": "Asia/Tashkent", "online_booking_enabled": true,
        "tagline": "Chilonzordagi eng yaxshi soch turmaklari", "logo": null, "cover": null, "brand_color": "#1E1B4B", "brand_color_2": null,
      },
      "services": [
        {
          "id": 11, "business_id": 2, "category_id": null, "name": "Soch olish + soqol", "duration_min": 40, "price_tiyin": 8000000,
          "deposit_tiyin": 2000000, "is_active": 1, "online_bookable": 1, "image": null, "description": null, "gallery": null,
          "created_at": 1784364000, "updated_at": 1784364000,
        },
      ],
      "staff": [
        {"id": 2, "name": "Usta Jahongir", "specialization": "Sartarosh"},
      ],
    },
  };

  static const Map<String, dynamic> napoleon = {
    "id": 61, "business_id": 3, "category_id": 7, "name": "Napoleon torti (1 kg)", "duration_min": 30, "price_tiyin": 22500000,
    "deposit_tiyin": null, "is_active": 1, "online_bookable": 0, "image": "https://api.tizbiz.uz/uploads/202609/n1.jpg",
    "description": "Uy usulida", "gallery": "[\"https://api.tizbiz.uz/uploads/202609/n2.jpg\"]",
    "created_at": 1784364000, "updated_at": 1784364000,
  };

  /// aziza-tortlari, catalog: category `Tortlar` with item 61 (225 000 so'm).
  static const Map<String, dynamic> siteCatalog = {
    "data": {
      "engine": "catalog",
      "business": {
        "id": 3, "name": "Aziza Tortlari", "slug": "aziza-tortlari", "category": "cafe", "phone": "+998902222222",
        "address": "Yunusobod 4-kvartal", "map_url": null, "timezone": "Asia/Tashkent", "online_booking_enabled": 1,
        "tagline": null, "logo": null, "cover": null, "brand_color": "#F26A35", "brand_color_2": null,
      },
      "categories": [
        {"id": 7, "name": "Tortlar", "image": null, "items": [napoleon]},
      ],
      "items": [napoleon],
    },
  };

  /// serenada, rental: staff 5 (the hall), service 40.
  static const Map<String, dynamic> siteRental = {
    "data": {
      "engine": "rental",
      "business": {
        "id": 5, "name": "Serenada", "slug": "serenada", "category": "rental", "phone": "+998904444444",
        "address": "Sergeli 7-mavze", "map_url": null, "timezone": "Asia/Tashkent", "online_booking_enabled": true,
        "tagline": "To'y va bazmlar uchun zal", "logo": null, "cover": null, "brand_color": "#7C3AED", "brand_color_2": null,
      },
      "services": [
        {
          "id": 40, "business_id": 5, "category_id": null, "name": "To'y zali", "duration_min": 360, "price_tiyin": 0,
          "deposit_tiyin": null, "is_active": 1, "online_bookable": 1, "image": null, "description": null, "gallery": null,
          "created_at": 1784364000, "updated_at": 1784364000,
        },
      ],
      "staff": [
        {"id": 5, "name": "Katta zal", "specialization": "500 o'rin"},
      ],
    },
  };

  static const Map<String, dynamic> uzi = {
    "id": 81, "business_id": 4, "category_id": 9, "name": "UZI tekshiruvi", "duration_min": 30, "price_tiyin": 15000000,
    "deposit_tiyin": null, "is_active": 1, "online_bookable": 1, "image": null, "description": "Qorin bo'shlig'i",
    "gallery": null, "created_at": 1784364000, "updated_at": 1784364000,
  };

  /// sanatrix, medical: catalog shape (categories/items, no staff).
  static const Map<String, dynamic> siteMedical = {
    "data": {
      "engine": "medical",
      "business": {
        "id": 4, "name": "Sanatrix", "slug": "sanatrix", "category": "clinic", "phone": "+998903333333",
        "address": "Mirobod tumani, 5-uy", "map_url": null, "timezone": "Asia/Tashkent", "online_booking_enabled": true,
        "tagline": "Oilaviy klinika", "logo": null, "cover": null, "brand_color": "#0F766E", "brand_color_2": null,
      },
      "categories": [
        {"id": 9, "name": "Diagnostika", "image": null, "items": [uzi]},
      ],
      "items": [uzi],
    },
  };

  /// GET /v1/staff/2/availability?date=2026-10-19&service_id=11.
  static const Map<String, dynamic> availability = {
    "data": {
      "date": "2026-10-19",
      "timezone": "Asia/Tashkent",
      "slots": [
        {"start_utc": "2026-10-19 04:00:00", "end_utc": "2026-10-19 04:40:00", "start_local": "09:00"},
        {"start_utc": "2026-10-19 05:00:00", "end_utc": "2026-10-19 05:40:00", "start_local": "10:00"},
        {"start_utc": "2026-10-19 13:00:00", "end_utc": "2026-10-19 13:40:00", "start_local": "18:00"},
      ],
    },
  };

  /// GET /v1/site/serenada/booked-days: one day both sessions, one evening only, one morning only.
  static const Map<String, dynamic> bookedDays = {
    "data": {
      "booked": {
        "2026-11-14": ["morning", "evening"],
        "2026-11-15": ["evening"],
        "2026-11-21": ["morning"],
      },
    },
  };
}
