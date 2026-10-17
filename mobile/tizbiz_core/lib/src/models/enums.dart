/// Implemented by every wire enum so the query encoder (and generic code) can read [wire].
abstract interface class WireEnum {
  /// The API's string value.
  String get wire;
}

/// Appointment status (one 'l' in canceled).
enum AppointmentStatus implements WireEnum {
  pending('pending', 'Kutilmoqda'),
  confirmed('confirmed', 'Tasdiqlangan'),
  arrived('arrived', 'Keldi'),
  completed('completed', 'Yakunlandi'),
  noShow('no_show', 'Kelmadi'),
  canceled('canceled', 'Bekor qilindi'),
  unknown('unknown', "Noma'lum");

  const AppointmentStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// Unknown or null -> [unknown].
  static AppointmentStatus fromWire(String? s) {
    for (final v in values) {
      if (v != unknown && v.wire == s) return v;
    }
    return unknown;
  }

  /// completed, noShow, canceled.
  bool get isTerminal => this == completed || this == noShow || this == canceled;

  /// pending, confirmed, arrived.
  bool get isLive => this == pending || this == confirmed || this == arrived;

  /// Server AppointmentController::TRANSITIONS (owner/admin, PATCH /v1/appointments/{id}).
  List<AppointmentStatus> get adminNext => switch (this) {
        pending => const [confirmed, arrived, completed, noShow, canceled],
        confirmed => const [arrived, completed, noShow, canceled],
        arrived => const [completed, noShow, canceled],
        _ => const <AppointmentStatus>[],
      };

  /// Staff table (PATCH /v1/me/appointments/{id}, BP §4.3) = adminNext minus canceled.
  List<AppointmentStatus> get staffNext => [
        for (final s in adminNext)
          if (s != canceled) s,
      ];
}

/// Order status (two 'l's in cancelled).
enum OrderStatus implements WireEnum {
  newOrder('new', 'Yangi'),
  confirmed('confirmed', 'Tasdiqlangan'),
  preparing('preparing', 'Tayyorlanmoqda'),
  ready('ready', 'Tayyor'),

  /// No delivery exists (phase-2 rule): 'handed over'.
  delivered('delivered', 'Topshirildi'),
  cancelled('cancelled', 'Bekor qilingan'),
  unknown('unknown', "Noma'lum");

  const OrderStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// Unknown or null -> [unknown].
  static OrderStatus fromWire(String? s) {
    for (final v in values) {
      if (v != unknown && v.wire == s) return v;
    }
    return unknown;
  }

  /// new, confirmed, preparing, ready (consumer scope=active).
  bool get isActive => this == newOrder || this == confirmed || this == preparing || this == ready;

  /// Kanban column order (web Orders.vue): new, confirmed, preparing, ready, delivered, cancelled.
  static const List<OrderStatus> board = [newOrder, confirmed, preparing, ready, delivered, cancelled];

  /// Suggested forward step for a one-tap button: new->confirmed->preparing->ready->delivered;
  /// else null.
  OrderStatus? get next => switch (this) {
        newOrder => confirmed,
        confirmed => preparing,
        preparing => ready,
        ready => delivered,
        _ => null,
      };
}

/// Business engine (storefront and admin behaviour).
enum Engine implements WireEnum {
  slot('slot', 'Navbat'),
  medical('medical', 'Tibbiyot'),
  catalog('catalog', 'Katalog'),
  rental('rental', 'Ijara');

  const Engine(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// null/unknown -> slot (site legacy payload has no engine).
  static Engine fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return slot;
  }

  /// Storefront is a menu/catalog with orders (MedicalEngine extends CatalogEngine).
  bool get isCatalogStorefront => this == catalog || this == medical;

  /// Admin Timetable shows a staff calendar (not OrdersTimeline).
  bool get hasTimetable => this != catalog;

  bool get isRental => this == rental;

  String get appointmentsTerm => switch (this) {
        slot => 'Navbatlar',
        catalog => 'Buyurtmalar',
        medical => 'Qabullar',
        rental => 'Ijaralar',
      };

  String get servicesTerm => switch (this) {
        slot => 'Xizmatlar',
        catalog => 'Menyu',
        medical => 'Xizmatlar',
        rental => 'Buyumlar',
      };

  String get staffTerm => switch (this) {
        slot => 'Ustalar',
        catalog => 'Xodimlar',
        medical => 'Shifokorlar',
        rental => 'Xodimlar',
      };
}

/// Business membership role.
enum BizRole implements WireEnum {
  owner('business_owner', 'Egasi'),
  admin('business_admin', 'Administrator'),
  staff('staff', 'Xodim'),
  unknown('', "Noma'lum");

  const BizRole(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// Unknown or null -> [unknown].
  static BizRole fromWire(String? s) {
    for (final v in values) {
      if (v != unknown && v.wire == s) return v;
    }
    return unknown;
  }

  /// owner || admin.
  bool get isManager => this == owner || this == admin;
}

/// Rental half-day session; null means the full day (10:00–23:00).
enum RentalSession implements WireEnum {
  morning('morning', 'Ertalab (10:00–16:00)'),
  evening('evening', 'Kechqurun (18:00–23:00)');

  const RentalSession(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// null / unknown -> null (= full day).
  static RentalSession? fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

enum Gender implements WireEnum {
  male('male', 'Erkak'),
  female('female', 'Ayol');

  const Gender(this.wire, this.label);

  @override
  final String wire;
  final String label;

  static Gender? fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

enum ReviewStatus implements WireEnum {
  published('published', 'Chop etilgan'),
  hidden('hidden', 'Yashirilgan');

  const ReviewStatus(this.wire, this.label);

  @override
  final String wire;
  final String label;

  /// Fallback published.
  static ReviewStatus fromWire(String? s) => s == hidden.wire ? hidden : published;
}

/// Only Payme is exposed in the apps (Click has a suspected tiyin/so'm 100x bug; BP §2f).
enum PaymentProvider implements WireEnum {
  payme('payme', 'Payme');

  const PaymentProvider(this.wire, this.label);

  @override
  final String wire;
  final String label;

  static PaymentProvider? fromWire(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}
