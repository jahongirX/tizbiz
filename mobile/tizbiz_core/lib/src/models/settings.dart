import 'package:meta/meta.dart';

import '../util/json_read.dart';

const Object _keep = Object();

/// GET/PUT /v1/settings/booking (live keys + BP 4.8 additions + PUT-only
/// telegram_webhook_ok/telegram_error).
@immutable
final class BookingSettings {
  const BookingSettings({
    required this.name,
    this.phone,
    this.tagline,
    required this.slug,
    this.onlineBookingEnabled = true,
    this.bookingLeadMin = 0,
    this.bookingHorizonDays = 30,
    this.logo,
    this.cover,
    this.brandColor,
    this.brandColor2,
    this.telegramConnected = false,
    this.telegramBotUsername,
    this.address,
    this.mapUrl,
    this.city,
    this.district,
    this.lat,
    this.lng,
    this.description,
    this.isListed = true,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.telegramWebhookOk,
    this.telegramError,
  });

  factory BookingSettings.fromJson(Map<String, dynamic> json) => BookingSettings(
        name: JsonRead.string(json['name']),
        phone: JsonRead.nonEmptyOrNull(json['phone']),
        tagline: JsonRead.nonEmptyOrNull(json['tagline']),
        slug: JsonRead.string(json['slug']),
        onlineBookingEnabled: JsonRead.boolean(json['online_booking_enabled'], true),
        bookingLeadMin: JsonRead.integer(json['booking_lead_min']),
        bookingHorizonDays: JsonRead.integer(json['booking_horizon_days'], 30),
        logo: JsonRead.nonEmptyOrNull(json['logo']),
        cover: JsonRead.nonEmptyOrNull(json['cover']),
        brandColor: JsonRead.nonEmptyOrNull(json['brand_color']),
        brandColor2: JsonRead.nonEmptyOrNull(json['brand_color_2']),
        telegramConnected: JsonRead.boolean(json['telegram_connected']),
        telegramBotUsername: JsonRead.nonEmptyOrNull(json['telegram_bot_username']),
        address: JsonRead.nonEmptyOrNull(json['address']),
        mapUrl: JsonRead.nonEmptyOrNull(json['map_url']),
        city: JsonRead.nonEmptyOrNull(json['city']),
        district: JsonRead.nonEmptyOrNull(json['district']),
        lat: JsonRead.numberOrNull(json['lat']),
        lng: JsonRead.numberOrNull(json['lng']),
        description: JsonRead.nonEmptyOrNull(json['description']),
        isListed: JsonRead.boolean(json['is_listed'], true),
        ratingAvg: JsonRead.number(json['rating_avg']),
        ratingCount: JsonRead.integer(json['rating_count']),
        telegramWebhookOk: JsonRead.booleanOrNull(json['telegram_webhook_ok']),
        telegramError: JsonRead.nonEmptyOrNull(json['telegram_error']),
      );

  final String name;
  final String? phone;
  final String? tagline;
  final String slug;
  final bool onlineBookingEnabled;
  final int bookingLeadMin;
  final int bookingHorizonDays;
  final String? logo;
  final String? cover;
  final String? brandColor;
  final String? brandColor2;

  /// Read-only.
  final bool telegramConnected;

  /// Read-only.
  final String? telegramBotUsername;

  /// NEW.
  final String? address;

  /// NEW.
  final String? mapUrl;

  /// NEW.
  final String? city;

  /// NEW.
  final String? district;

  /// NEW.
  final double? lat;

  /// NEW.
  final double? lng;

  /// NEW.
  final String? description;

  /// NEW, default true.
  final bool isListed;

  /// NEW, read-only.
  final double ratingAvg;

  /// NEW, read-only.
  final int ratingCount;

  /// Only right after a token PUT.
  final bool? telegramWebhookOk;
  final String? telegramError;

  static const Set<String> writableKeys = {
    'name', 'phone', 'tagline', 'slug', 'online_booking_enabled', //
    'booking_lead_min', 'booking_horizon_days', 'logo', 'cover', 'brand_color', 'brand_color_2',
    'address', 'map_url', 'city', 'district', 'lat', 'lng', 'description', 'is_listed',
  };

  /// Writable keys that are required (never cleared to null).
  static const Set<String> _requiredKeys = {'name', 'slug'};

  /// Partial PUT body: only writable keys whose value differs from [original]; a value cleared to
  /// null/'' is sent as null (server clears it). Empty map = nothing to save.
  Map<String, dynamic> diff(BookingSettings original) {
    final now = toJson();
    final before = original.toJson();
    Object? norm(String key, Object? v) {
      if (v is String) {
        final t = v.trim();
        if (t.isEmpty && !_requiredKeys.contains(key)) return null;
        return _requiredKeys.contains(key) ? t : v;
      }
      return v;
    }

    final out = <String, dynamic>{};
    for (final key in writableKeys) {
      final a = norm(key, now[key]);
      final b = norm(key, before[key]);
      if (a != b) out[key] = a;
    }
    return out;
  }

  /// Every writable field. Nullable fields use a sentinel so they can be set to null.
  BookingSettings copyWith({
    String? name,
    Object? phone = _keep,
    Object? tagline = _keep,
    String? slug,
    bool? onlineBookingEnabled,
    int? bookingLeadMin,
    int? bookingHorizonDays,
    Object? logo = _keep,
    Object? cover = _keep,
    Object? brandColor = _keep,
    Object? brandColor2 = _keep,
    Object? address = _keep,
    Object? mapUrl = _keep,
    Object? city = _keep,
    Object? district = _keep,
    Object? lat = _keep,
    Object? lng = _keep,
    Object? description = _keep,
    bool? isListed,
  }) {
    T? pick<T>(Object? v, T? current) => identical(v, _keep) ? current : v as T?;
    return BookingSettings(
      name: name ?? this.name,
      phone: pick<String>(phone, this.phone),
      tagline: pick<String>(tagline, this.tagline),
      slug: slug ?? this.slug,
      onlineBookingEnabled: onlineBookingEnabled ?? this.onlineBookingEnabled,
      bookingLeadMin: bookingLeadMin ?? this.bookingLeadMin,
      bookingHorizonDays: bookingHorizonDays ?? this.bookingHorizonDays,
      logo: pick<String>(logo, this.logo),
      cover: pick<String>(cover, this.cover),
      brandColor: pick<String>(brandColor, this.brandColor),
      brandColor2: pick<String>(brandColor2, this.brandColor2),
      telegramConnected: telegramConnected,
      telegramBotUsername: telegramBotUsername,
      address: pick<String>(address, this.address),
      mapUrl: pick<String>(mapUrl, this.mapUrl),
      city: pick<String>(city, this.city),
      district: pick<String>(district, this.district),
      lat: pick<double>(lat is int ? lat.toDouble() : lat, this.lat),
      lng: pick<double>(lng is int ? lng.toDouble() : lng, this.lng),
      description: pick<String>(description, this.description),
      isListed: isListed ?? this.isListed,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      telegramWebhookOk: telegramWebhookOk,
      telegramError: telegramError,
    );
  }

  /// Telegram connect/disconnect body: {'telegram_bot_token': token} ('' disconnects).
  static Map<String, dynamic> telegramTokenBody(String token) => {'telegram_bot_token': token};

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'tagline': tagline,
        'slug': slug,
        'online_booking_enabled': onlineBookingEnabled,
        'booking_lead_min': bookingLeadMin,
        'booking_horizon_days': bookingHorizonDays,
        'logo': logo,
        'cover': cover,
        'brand_color': brandColor,
        'brand_color_2': brandColor2,
        'telegram_connected': telegramConnected,
        'telegram_bot_username': telegramBotUsername,
        'address': address,
        'map_url': mapUrl,
        'city': city,
        'district': district,
        'lat': lat,
        'lng': lng,
        'description': description,
        'is_listed': isListed,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'telegram_webhook_ok': telegramWebhookOk,
        'telegram_error': telegramError,
      };
}
