import 'package:meta/meta.dart';

import '../format/phone.dart';
import '../time/dates.dart';
import '../time/local_date.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'enums.dart';

/// ConsumerUser::fields() (BP 3.2: id, phone, name, birthday, gender, city, locale, created_at)
/// + GET /me stats.
@immutable
final class ConsumerUser {
  const ConsumerUser({
    required this.id,
    required this.phone,
    this.name,
    this.birthday,
    this.gender,
    this.city,
    this.locale = 'uz',
    this.createdAt,
    this.stats,
  });

  factory ConsumerUser.fromJson(Map<String, dynamic> json) {
    final stats = JsonRead.objectOrNull(json['stats']);
    return ConsumerUser(
      id: JsonRead.integer(json['id']),
      phone: JsonRead.string(json['phone']),
      name: JsonRead.nonEmptyOrNull(json['name']),
      birthday: JsonRead.date(json['birthday']),
      gender: Gender.fromWire(JsonRead.stringOrNull(json['gender'])),
      city: JsonRead.nonEmptyOrNull(json['city']),
      locale: JsonRead.nonEmptyOrNull(json['locale']) ?? 'uz',
      createdAt: JsonRead.unix(json['created_at']),
      stats: stats == null ? null : ConsumerStats.fromJson(stats),
    );
  }

  final int id;
  final String phone;
  final String? name;
  final LocalDate? birthday;
  final Gender? gender;
  final String? city;

  /// 'uz' | 'ru', default 'uz'.
  final String locale;
  final DateTime? createdAt;

  /// GET/PATCH /v1/consumer/me only.
  final ConsumerStats? stats;

  /// name ?? Phone.format(phone).
  String get displayName => name ?? Phone.format(phone);

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'birthday': birthday?.toIso(),
        'gender': gender?.wire,
        'city': city,
        'locale': locale,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'stats': stats?.toJson(),
      };
}

@immutable
final class ConsumerStats {
  const ConsumerStats({
    this.appointmentsUpcoming = 0,
    this.appointmentsTotal = 0,
    this.ordersTotal = 0,
    this.reviewsTotal = 0,
    this.favoritesTotal = 0,
  });

  factory ConsumerStats.fromJson(Map<String, dynamic> json) => ConsumerStats(
        appointmentsUpcoming: JsonRead.integer(json['appointments_upcoming']),
        appointmentsTotal: JsonRead.integer(json['appointments_total']),
        ordersTotal: JsonRead.integer(json['orders_total']),
        reviewsTotal: JsonRead.integer(json['reviews_total']),
        favoritesTotal: JsonRead.integer(json['favorites_total']),
      );

  final int appointmentsUpcoming;
  final int appointmentsTotal;
  final int ordersTotal;
  final int reviewsTotal;
  final int favoritesTotal;

  Map<String, dynamic> toJson() => {
        'appointments_upcoming': appointmentsUpcoming,
        'appointments_total': appointmentsTotal,
        'orders_total': ordersTotal,
        'reviews_total': reviewsTotal,
        'favorites_total': favoritesTotal,
      };
}

/// POST /v1/consumer/auth/otp.
@immutable
final class OtpSent {
  const OtpSent({this.sent = true, this.ttlSec = 120, this.retryAfterSec = 60});

  factory OtpSent.fromJson(Map<String, dynamic> json) => OtpSent(
        sent: JsonRead.boolean(json['sent'], true),
        ttlSec: JsonRead.integer(json['ttl_sec'], 120),
        retryAfterSec: JsonRead.integer(json['retry_after_sec'], 60),
      );

  final bool sent;

  /// 120.
  final int ttlSec;

  /// 60.
  final int retryAfterSec;

  Map<String, dynamic> toJson() => {'sent': sent, 'ttl_sec': ttlSec, 'retry_after_sec': retryAfterSec};
}

/// POST /v1/consumer/auth/verify.
@immutable
final class ConsumerSession {
  const ConsumerSession({required this.token, this.expiresAt, this.isNew = false, required this.consumer});

  factory ConsumerSession.fromJson(Map<String, dynamic> json) => ConsumerSession(
        token: JsonRead.string(json['token']),
        expiresAt: JsonRead.unix(json['expires_at']),
        isNew: JsonRead.boolean(json['is_new']),
        consumer: ConsumerUser.fromJson(JsonRead.objectOrNull(json['consumer']) ?? const <String, dynamic>{}),
      );

  /// typ=consumer, 30 days.
  final String token;

  /// Unix.
  final DateTime? expiresAt;
  final bool isNew;
  final ConsumerUser consumer;

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires_at': expiresAt == null ? null : Dates.toUnix(expiresAt!),
        'is_new': isNew,
        'consumer': consumer.toJson(),
      };
}

/// GET /v1/consumer/loyalty item.
@immutable
final class LoyaltyWalletEntry {
  const LoyaltyWalletEntry({
    required this.business,
    required this.clientId,
    this.points = 0,
    this.cashbackTiyin = 0,
    this.depositBalanceTiyin = 0,
    this.visits = 0,
  });

  factory LoyaltyWalletEntry.fromJson(Map<String, dynamic> json) => LoyaltyWalletEntry(
        business: BusinessRef.fromJson(JsonRead.objectOrNull(json['business']) ?? const <String, dynamic>{}),
        clientId: JsonRead.integer(json['client_id']),
        points: JsonRead.integer(json['points']),
        cashbackTiyin: JsonRead.integer(json['cashback_tiyin']),
        depositBalanceTiyin: JsonRead.integer(json['deposit_balance_tiyin']),
        visits: JsonRead.integer(json['visits']),
      );

  /// {id, slug, name, logo, brand_color}.
  final BusinessRef business;
  final int clientId;
  final int points;
  final int cashbackTiyin;
  final int depositBalanceTiyin;
  final int visits;

  Map<String, dynamic> toJson() => {
        'business': business.toJson(),
        'client_id': clientId,
        'points': points,
        'cashback_tiyin': cashbackTiyin,
        'deposit_balance_tiyin': depositBalanceTiyin,
        'visits': visits,
      };
}
