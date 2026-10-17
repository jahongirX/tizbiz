import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../util/json_read.dart';
import 'business.dart';

/// Service / menu item / rental item. Raw AR row (live: all columns) on /v1/services and
/// /v1/site/{slug}.
@immutable
final class Service {
  const Service({
    required this.id,
    this.businessId,
    this.categoryId,
    required this.name,
    this.durationMin = 30,
    this.priceTiyin = 0,
    this.depositTiyin,
    this.isActive = true,
    this.onlineBookable = true,
    this.image,
    this.description,
    this.gallery = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: JsonRead.integer(json['id']),
        businessId: JsonRead.integerOrNull(json['business_id']),
        categoryId: JsonRead.integerOrNull(json['category_id']),
        name: JsonRead.string(json['name']),
        durationMin: JsonRead.integer(json['duration_min'], 30),
        priceTiyin: JsonRead.integer(json['price_tiyin']),
        depositTiyin: JsonRead.integerOrNull(json['deposit_tiyin']),
        isActive: JsonRead.boolean(json['is_active'], true),
        onlineBookable: JsonRead.boolean(json['online_bookable'], true),
        image: JsonRead.nonEmptyOrNull(json['image']),
        description: JsonRead.nonEmptyOrNull(json['description']),
        gallery: JsonRead.stringList(json['gallery']),
        createdAt: JsonRead.unix(json['created_at']),
        updatedAt: JsonRead.unix(json['updated_at']),
      );

  final int id;
  final int? businessId;
  final int? categoryId;
  final String name;

  /// Default 30.
  final int durationMin;
  final int priceTiyin;

  /// null/0 = no prepayment.
  final int? depositTiyin;
  final bool isActive;
  final bool onlineBookable;
  final String? image;
  final String? description;

  /// null -> [].
  final List<String> gallery;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get requiresDeposit => (depositTiyin ?? 0) > 0;

  /// Body for POST/PATCH /v1/services: name, category_id, duration_min, price_tiyin, deposit_tiyin,
  /// is_active, online_bookable, image, description, gallery.
  Map<String, dynamic> toInput() => {
        'name': name,
        'category_id': categoryId,
        'duration_min': durationMin,
        'price_tiyin': priceTiyin,
        'deposit_tiyin': depositTiyin,
        'is_active': isActive,
        'online_bookable': onlineBookable,
        'image': image,
        'description': description,
        'gallery': gallery,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        ...toInput(),
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
      };
}

@immutable
final class ServiceCategory {
  const ServiceCategory({required this.id, this.businessId, required this.name, this.sort = 0, this.image});

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: JsonRead.integer(json['id']),
        businessId: JsonRead.integerOrNull(json['business_id']),
        name: JsonRead.string(json['name']),
        sort: JsonRead.integer(json['sort']),
        image: JsonRead.nonEmptyOrNull(json['image']),
      );

  final int id;
  final int? businessId;
  final String name;
  final int sort;
  final String? image;

  /// {name, sort, image}.
  Map<String, dynamic> toInput() => {'name': name, 'sort': sort, 'image': image};

  Map<String, dynamic> toJson() => {'id': id, 'business_id': businessId, ...toInput()};
}

/// Staff member. Shapes: business GET /v1/staff (live: id, business_id, user_id, name,
/// specialization, is_active, created_at, updated_at, commission_percent); public site
/// (BP 4.5: id, name, specialization); GET /v1/me/staff (BP 4.3: + business
/// {id,name,slug,engine,timezone,logo}).
@immutable
final class Staff {
  const Staff({
    required this.id,
    this.businessId,
    this.userId,
    required this.name,
    this.specialization,
    this.commissionPercent,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.business,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    final business = JsonRead.objectOrNull(json['business']);
    return Staff(
      id: JsonRead.integer(json['id']),
      businessId: JsonRead.integerOrNull(json['business_id']),
      userId: JsonRead.integerOrNull(json['user_id']),
      name: JsonRead.string(json['name']),
      specialization: JsonRead.nonEmptyOrNull(json['specialization']),
      commissionPercent: JsonRead.integerOrNull(json['commission_percent']),
      isActive: JsonRead.boolean(json['is_active'], true),
      createdAt: JsonRead.unix(json['created_at']),
      updatedAt: JsonRead.unix(json['updated_at']),
      business: business == null ? null : BusinessRef.fromJson(business),
    );
  }

  final int id;
  final int? businessId;
  final int? userId;
  final String name;
  final String? specialization;

  /// 0..100.
  final int? commissionPercent;

  /// Default true when missing.
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// me/staff only.
  final BusinessRef? business;

  /// Body for POST/PATCH /v1/staff: name, specialization, is_active, commission_percent.
  Map<String, dynamic> toInput() => {
        'name': name,
        'specialization': specialization,
        'is_active': isActive,
        'commission_percent': commissionPercent,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'user_id': userId,
        ...toInput(),
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
        'business': business?.toJson(),
      };
}
