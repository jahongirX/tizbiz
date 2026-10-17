import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../time/hm_time.dart';
import '../time/local_date.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'catalog.dart';
import 'enums.dart';

/// GET /v1/site/{slug}. slot/rental: business, services, staff. catalog/medical: business,
/// categories, items.
@immutable
final class StorefrontData {
  const StorefrontData({
    this.engine = Engine.slot,
    required this.business,
    this.services = const [],
    this.staff = const [],
    this.categories = const [],
    this.items = const [],
  });

  factory StorefrontData.fromJson(Map<String, dynamic> json) => StorefrontData(
        engine: Engine.fromWire(JsonRead.stringOrNull(json['engine'])),
        business: SiteBusiness.fromJson(JsonRead.objectOrNull(json['business']) ?? const <String, dynamic>{}),
        services: JsonRead.list(json['services'], Service.fromJson),
        staff: JsonRead.list(json['staff'], Staff.fromJson),
        categories: JsonRead.list(json['categories'], CatalogCategory.fromJson),
        items: JsonRead.list(json['items'], Service.fromJson),
      );

  /// Missing -> slot.
  final Engine engine;
  final SiteBusiness business;

  /// [] for catalog engines or when booking is off.
  final List<Service> services;

  /// Public shape.
  final List<Staff> staff;

  /// Catalog engines.
  final List<CatalogCategory> categories;

  /// Catalog engines, all active.
  final List<Service> items;

  Map<String, dynamic> toJson() => {
        'engine': engine.wire,
        'business': business.toJson(),
        'services': [for (final s in services) s.toJson()],
        'staff': [for (final s in staff) s.toJson()],
        'categories': [for (final c in categories) c.toJson()],
        'items': [for (final i in items) i.toJson()],
      };
}

@immutable
final class CatalogCategory {
  const CatalogCategory({required this.id, required this.name, this.image, this.items = const []});

  factory CatalogCategory.fromJson(Map<String, dynamic> json) => CatalogCategory(
        id: JsonRead.integer(json['id']),
        name: JsonRead.string(json['name']),
        image: JsonRead.nonEmptyOrNull(json['image']),
        items: JsonRead.list(json['items'], Service.fromJson),
      );

  /// 0 = 'Boshqa', uncategorised.
  final int id;
  final String name;
  final String? image;
  final List<Service> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'items': [for (final i in items) i.toJson()],
      };
}

/// GET /v1/staff/{id}/availability (live).
@immutable
final class Availability {
  const Availability({required this.date, this.timezone = Dates.defaultTimezone, this.slots = const []});

  factory Availability.fromJson(Map<String, dynamic> json) => Availability(
        date: JsonRead.date(json['date']) ?? const LocalDate(1970, 1, 1),
        timezone: JsonRead.nonEmptyOrNull(json['timezone']) ?? Dates.defaultTimezone,
        slots: JsonRead.list(json['slots'], AvailabilitySlot.fromJson),
      );

  /// Business-local.
  final LocalDate date;
  final String timezone;
  final List<AvailabilitySlot> slots;

  Map<String, dynamic> toJson() => {
        'date': date.toIso(),
        'timezone': timezone,
        'slots': [for (final s in slots) s.toJson()],
      };
}

@immutable
final class AvailabilitySlot {
  const AvailabilitySlot({required this.startUtc, required this.endUtc, required this.startLocal});

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final start = JsonRead.utc(json['start_utc']) ?? DateTime.utc(1970);
    return AvailabilitySlot(
      startUtc: start,
      endUtc: JsonRead.utc(json['end_utc']) ?? start,
      startLocal: JsonRead.time(json['start_local']) ?? Dates.toBizLocal(start).time,
    );
  }

  /// 'Y-m-d H:i:s' UTC -> echo back as POST starts_at.
  final DateTime startUtc;
  final DateTime endUtc;

  /// 'HH:MM'.
  final HmTime startLocal;

  /// 'morning' < 12:00, 'afternoon' < 17:00, else 'evening' (booking SPA slotBucket).
  String get bucket {
    final h = startLocal.hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  Map<String, dynamic> toJson() => {
        'start_utc': Dates.formatApiUtc(startUtc),
        'end_utc': Dates.formatApiUtc(endUtc),
        'start_local': startLocal.format(),
      };
}

/// GET /v1/site/{slug}/booked-days -> {"booked": {"2026-11-14": ["evening"]}}; empty may be {} or [].
@immutable
final class BookedDays {
  const BookedDays({this.booked = const {}});

  factory BookedDays.fromJson(Map<String, dynamic> json) {
    final raw = JsonRead.objectOrNull(json['booked']) ?? const <String, dynamic>{};
    final booked = <LocalDate, Set<RentalSession>>{};
    for (final e in raw.entries) {
      final day = LocalDate.tryParse(e.key);
      if (day == null) continue;
      booked[day] = {
        for (final s in JsonRead.stringList(e.value))
          if (RentalSession.fromWire(s) case final RentalSession session) session,
      };
    }
    return BookedDays(booked: booked);
  }

  final Map<LocalDate, Set<RentalSession>> booked;

  /// Both sessions taken.
  bool isFullyBooked(LocalDate d) {
    final s = booked[d];
    return s != null && RentalSession.values.every(s.contains);
  }

  /// session null (full day) = any session taken.
  bool isTaken(LocalDate d, RentalSession? session) {
    final s = booked[d];
    if (s == null || s.isEmpty) return false;
    return session == null || s.contains(session);
  }

  /// {'booked': {iso: [wire, ...]}} (sessions sorted morning, evening).
  Map<String, dynamic> toJson() => {
        'booked': {
          for (final e in booked.entries)
            e.key.toIso(): [
              for (final s in RentalSession.values)
                if (e.value.contains(s)) s.wire,
            ],
        },
      };
}
