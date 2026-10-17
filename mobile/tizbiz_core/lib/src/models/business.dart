import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../time/hm_time.dart';
import '../util/json_read.dart';
import 'enums.dart';
import 'review.dart';

/// Compact business subset. Shapes: consumer appointments/orders (BP 4.6: id, slug, name, logo,
/// brand_color, phone, address, map_url, timezone, engine), loyalty (id, slug, name, logo,
/// brand_color), reviews.mine (id, slug, name, logo), me/staff (id, name, slug, engine, timezone,
/// logo). Missing keys -> null.
@immutable
final class BusinessRef {
  const BusinessRef({
    required this.id,
    this.slug = '',
    this.name = '',
    this.logo,
    this.brandColor,
    this.phone,
    this.address,
    this.mapUrl,
    this.timezone,
    this.engine = Engine.slot,
  });

  factory BusinessRef.fromJson(Map<String, dynamic> json) => BusinessRef(
        id: JsonRead.integer(json['id']),
        slug: JsonRead.string(json['slug']),
        name: JsonRead.string(json['name']),
        logo: JsonRead.nonEmptyOrNull(json['logo']),
        brandColor: JsonRead.nonEmptyOrNull(json['brand_color']),
        phone: JsonRead.nonEmptyOrNull(json['phone']),
        address: JsonRead.nonEmptyOrNull(json['address']),
        mapUrl: JsonRead.nonEmptyOrNull(json['map_url']),
        timezone: JsonRead.nonEmptyOrNull(json['timezone']),
        engine: Engine.fromWire(JsonRead.stringOrNull(json['engine'])),
      );

  final int id;
  final String slug;
  final String name;
  final String? logo;
  final String? brandColor;
  final String? phone;
  final String? address;
  final String? mapUrl;

  /// null -> use Dates.defaultTimezone.
  final String? timezone;
  final Engine engine;

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'logo': logo,
        'brand_color': brandColor,
        'phone': phone,
        'address': address,
        'map_url': mapUrl,
        'timezone': timezone,
        'engine': engine.wire,
      };
}

/// Directory card (BP 4.4 GET /v1/directory/businesses; also consumer favorites).
@immutable
final class BusinessCard {
  const BusinessCard({
    required this.id,
    required this.slug,
    required this.name,
    this.category,
    this.categoryLabel,
    this.engine = Engine.slot,
    this.tagline,
    this.logo,
    this.cover,
    this.brandColor,
    this.brandColor2,
    this.address,
    this.city,
    this.district,
    this.lat,
    this.lng,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isFeatured = false,
    this.onlineBookingEnabled = true,
    this.priceFromTiyin,
    this.isFavorite = false,
  });

  factory BusinessCard.fromJson(Map<String, dynamic> json) => BusinessCard(
        id: JsonRead.integer(json['id']),
        slug: JsonRead.string(json['slug']),
        name: JsonRead.string(json['name']),
        category: JsonRead.nonEmptyOrNull(json['category']),
        categoryLabel: JsonRead.nonEmptyOrNull(json['category_label']),
        engine: Engine.fromWire(JsonRead.stringOrNull(json['engine'])),
        tagline: JsonRead.nonEmptyOrNull(json['tagline']),
        logo: JsonRead.nonEmptyOrNull(json['logo']),
        cover: JsonRead.nonEmptyOrNull(json['cover']),
        brandColor: JsonRead.nonEmptyOrNull(json['brand_color']),
        brandColor2: JsonRead.nonEmptyOrNull(json['brand_color_2']),
        address: JsonRead.nonEmptyOrNull(json['address']),
        city: JsonRead.nonEmptyOrNull(json['city']),
        district: JsonRead.nonEmptyOrNull(json['district']),
        lat: JsonRead.numberOrNull(json['lat']),
        lng: JsonRead.numberOrNull(json['lng']),
        ratingAvg: JsonRead.number(json['rating_avg']),
        ratingCount: JsonRead.integer(json['rating_count']),
        isFeatured: JsonRead.boolean(json['is_featured']),
        onlineBookingEnabled: JsonRead.boolean(json['online_booking_enabled'], true),
        priceFromTiyin: JsonRead.integerOrNull(json['price_from_tiyin']),
        isFavorite: JsonRead.boolean(json['is_favorite']),
      );

  final int id;
  final String slug;
  final String name;

  /// barber|cafe|restaurant|clinic|rental|...
  final String? category;
  final String? categoryLabel;
  final Engine engine;
  final String? tagline;
  final String? logo;
  final String? cover;
  final String? brandColor;
  final String? brandColor2;
  final String? address;
  final String? city;
  final String? district;

  /// Float, or decimal string, or null on the wire.
  final double? lat;
  final double? lng;
  final double ratingAvg;
  final int ratingCount;
  final bool isFeatured;
  final bool onlineBookingEnabled;
  final int? priceFromTiyin;

  /// Always present; false when anonymous.
  final bool isFavorite;

  bool get hasLocation => lat != null && lng != null;

  BusinessCard copyWith({bool? isFavorite}) => BusinessCard(
        id: id,
        slug: slug,
        name: name,
        category: category,
        categoryLabel: categoryLabel,
        engine: engine,
        tagline: tagline,
        logo: logo,
        cover: cover,
        brandColor: brandColor,
        brandColor2: brandColor2,
        address: address,
        city: city,
        district: district,
        lat: lat,
        lng: lng,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
        isFeatured: isFeatured,
        onlineBookingEnabled: onlineBookingEnabled,
        priceFromTiyin: priceFromTiyin,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'category': category,
        'category_label': categoryLabel,
        'engine': engine.wire,
        'tagline': tagline,
        'logo': logo,
        'cover': cover,
        'brand_color': brandColor,
        'brand_color_2': brandColor2,
        'address': address,
        'city': city,
        'district': district,
        'lat': lat,
        'lng': lng,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'is_featured': isFeatured,
        'online_booking_enabled': onlineBookingEnabled,
        'price_from_tiyin': priceFromTiyin,
        'is_favorite': isFavorite,
      };
}

/// GET /v1/directory/businesses/{slug} -> data.business. Every card field + detail fields.
@immutable
final class BusinessDetail {
  const BusinessDetail({
    required this.card,
    this.phone,
    this.mapUrl,
    this.description,
    this.timezone = Dates.defaultTimezone,
    this.telegramBotUsername,
    this.hours = const [],
  });

  factory BusinessDetail.fromJson(Map<String, dynamic> json) => BusinessDetail(
        card: BusinessCard.fromJson(json),
        phone: JsonRead.nonEmptyOrNull(json['phone']),
        mapUrl: JsonRead.nonEmptyOrNull(json['map_url']),
        description: JsonRead.nonEmptyOrNull(json['description']),
        timezone: JsonRead.nonEmptyOrNull(json['timezone']) ?? Dates.defaultTimezone,
        telegramBotUsername: JsonRead.nonEmptyOrNull(json['telegram_bot_username']),
        hours: JsonRead.list(json['hours'], OpeningHours.fromJson),
      );

  /// Parsed from the SAME map (card keys).
  final BusinessCard card;
  final String? phone;
  final String? mapUrl;
  final String? description;

  /// Fallback 'Asia/Tashkent'.
  final String timezone;
  final String? telegramBotUsername;
  final List<OpeningHours> hours;

  BusinessDetail copyWith({BusinessCard? card}) => BusinessDetail(
        card: card ?? this.card,
        phone: phone,
        mapUrl: mapUrl,
        description: description,
        timezone: timezone,
        telegramBotUsername: telegramBotUsername,
        hours: hours,
      );

  /// card.toJson() merged with the detail keys (flat, as on the wire).
  Map<String, dynamic> toJson() => {
        ...card.toJson(),
        'phone': phone,
        'map_url': mapUrl,
        'description': description,
        'timezone': timezone,
        'telegram_bot_username': telegramBotUsername,
        'hours': [for (final h in hours) h.toJson()],
      };
}

@immutable
final class OpeningHours {
  const OpeningHours({required this.weekday, required this.open, required this.close});

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        weekday: JsonRead.integer(json['weekday'], 1),
        open: JsonRead.time(json['open']) ?? const HmTime(0, 0),
        close: JsonRead.time(json['close']) ?? const HmTime(0, 0),
      );

  /// ISO 1..7.
  final int weekday;

  /// 'HH:MM'.
  final HmTime open;

  /// 'HH:MM'.
  final HmTime close;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'open': open.format(), 'close': close.format()};
}

/// Whole GET /v1/directory/businesses/{slug} payload.
@immutable
final class BusinessPage {
  const BusinessPage({
    required this.business,
    this.rating = RatingSummary.empty,
    this.reviewsPreview = const [],
    this.isFavorite = false,
  });

  factory BusinessPage.fromJson(Map<String, dynamic> json) {
    final rating = JsonRead.objectOrNull(json['rating']);
    return BusinessPage(
      business: BusinessDetail.fromJson(JsonRead.objectOrNull(json['business']) ?? const <String, dynamic>{}),
      rating: rating == null ? RatingSummary.empty : RatingSummary.fromJson(rating),
      reviewsPreview: JsonRead.list(json['reviews_preview'], Review.fromJson),
      isFavorite: JsonRead.boolean(json['is_favorite']),
    );
  }

  final BusinessDetail business;

  /// {avg, count, distribution}.
  final RatingSummary rating;
  final List<Review> reviewsPreview;
  final bool isFavorite;

  /// Also updates business.card.isFavorite.
  BusinessPage copyWith({bool? isFavorite}) => BusinessPage(
        business: isFavorite == null
            ? business
            : business.copyWith(card: business.card.copyWith(isFavorite: isFavorite)),
        rating: rating,
        reviewsPreview: reviewsPreview,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => {
        'business': business.toJson(),
        'rating': rating.toJson(),
        'reviews_preview': [for (final r in reviewsPreview) r.toJson()],
        'is_favorite': isFavorite,
      };
}

/// GET /v1/directory/categories item (BP 4.4).
@immutable
final class Category {
  const Category({
    required this.key,
    required this.label,
    this.labelRu,
    this.engine = Engine.slot,
    this.icon = '',
    this.count = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        key: JsonRead.string(json['key']),
        label: JsonRead.string(json['label']),
        labelRu: JsonRead.nonEmptyOrNull(json['label_ru']),
        engine: Engine.fromWire(JsonRead.stringOrNull(json['engine'])),
        icon: JsonRead.string(json['icon']),
        count: JsonRead.integer(json['count']),
      );

  /// barber|cafe|restaurant|clinic|rental.
  final String key;
  final String label;
  final String? labelRu;
  final Engine engine;

  /// scissors|cake|utensils|stethoscope|rings.
  final String icon;
  final int count;

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'label_ru': labelRu,
        'engine': engine.wire,
        'icon': icon,
        'count': count,
      };
}

/// GET /v1/site/{slug} -> business (SlotEngine::businessPayload / BusinessPresenter::site, live).
/// The legacy branch omits address/branding: all nullable.
@immutable
final class SiteBusiness {
  const SiteBusiness({
    required this.id,
    required this.name,
    required this.slug,
    this.category,
    this.phone,
    this.address,
    this.mapUrl,
    this.timezone = Dates.defaultTimezone,
    this.onlineBookingEnabled = true,
    this.tagline,
    this.logo,
    this.cover,
    this.brandColor,
    this.brandColor2,
  });

  factory SiteBusiness.fromJson(Map<String, dynamic> json) => SiteBusiness(
        id: JsonRead.integer(json['id']),
        name: JsonRead.string(json['name']),
        slug: JsonRead.string(json['slug']),
        category: JsonRead.nonEmptyOrNull(json['category']),
        phone: JsonRead.nonEmptyOrNull(json['phone']),
        address: JsonRead.nonEmptyOrNull(json['address']),
        mapUrl: JsonRead.nonEmptyOrNull(json['map_url']),
        timezone: JsonRead.nonEmptyOrNull(json['timezone']) ?? Dates.defaultTimezone,
        onlineBookingEnabled: JsonRead.boolean(json['online_booking_enabled'], true),
        tagline: JsonRead.nonEmptyOrNull(json['tagline']),
        logo: JsonRead.nonEmptyOrNull(json['logo']),
        cover: JsonRead.nonEmptyOrNull(json['cover']),
        brandColor: JsonRead.nonEmptyOrNull(json['brand_color']),
        brandColor2: JsonRead.nonEmptyOrNull(json['brand_color_2']),
      );

  final int id;
  final String name;
  final String slug;
  final String? category;
  final String? phone;
  final String? address;
  final String? mapUrl;

  /// Fallback 'Asia/Tashkent'.
  final String timezone;

  /// Default true when missing.
  final bool onlineBookingEnabled;
  final String? tagline;
  final String? logo;
  final String? cover;
  final String? brandColor;
  final String? brandColor2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'phone': phone,
        'address': address,
        'map_url': mapUrl,
        'timezone': timezone,
        'online_booking_enabled': onlineBookingEnabled,
        'tagline': tagline,
        'logo': logo,
        'cover': cover,
        'brand_color': brandColor,
        'brand_color_2': brandColor2,
      };
}

/// Business-app membership (login/me businesses[]; live AuthController).
@immutable
final class BusinessMembership {
  const BusinessMembership({
    required this.id,
    required this.name,
    required this.slug,
    this.category,
    this.engine = Engine.slot,
    this.logo,
    this.role = BizRole.unknown,
  });

  factory BusinessMembership.fromJson(Map<String, dynamic> json) => BusinessMembership(
        id: JsonRead.integer(json['id']),
        name: JsonRead.string(json['name']),
        slug: JsonRead.string(json['slug']),
        category: JsonRead.nonEmptyOrNull(json['category']),
        engine: Engine.fromWire(JsonRead.stringOrNull(json['engine'])),
        logo: JsonRead.nonEmptyOrNull(json['logo']),
        role: BizRole.fromWire(JsonRead.stringOrNull(json['role'])),
      );

  final int id;
  final String name;
  final String slug;
  final String? category;
  final Engine engine;
  final String? logo;
  final BizRole role;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'category': category,
        'engine': engine.wire,
        'logo': logo,
        'role': role.wire,
      };
}
