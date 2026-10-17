import 'package:meta/meta.dart';

import '../time/biz_time.dart';
import '../time/dates.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'enums.dart';

const Object _keep = Object();

/// One class for both appointment shapes:
/// - business shape (`Appointment::fields()`, live + BP 4.3): flat staff_id, service_id,
///   client_name, client_phone, service_name, service_duration, staff_name, items;
/// - consumer shape (BP 4.6): nested business, staff{id,name},
///   service{id,name,duration_min,price_tiyin} plus can_cancel, can_review, review_id.
///
/// Parsing prefers the flat key and falls back to the nested one.
@immutable
final class Appointment {
  const Appointment({
    required this.id,
    this.businessId,
    this.clientId,
    this.consumerId,
    required this.staffId,
    required this.serviceId,
    this.guests,
    required this.startsAt,
    required this.endsAt,
    this.status = AppointmentStatus.unknown,
    this.source,
    this.depositTiyin,
    this.paid = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.clientName,
    this.clientPhone,
    this.serviceName,
    this.serviceDuration,
    this.servicePriceTiyin,
    this.staffName,
    this.items = const [],
    this.business,
    this.canCancel,
    this.canReview,
    this.reviewId,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final businessMap = JsonRead.objectOrNull(json['business']);
    final staff = JsonRead.objectOrNull(json['staff']) ?? const <String, dynamic>{};
    final service = JsonRead.objectOrNull(json['service']) ?? const <String, dynamic>{};
    final business = businessMap == null ? null : BusinessRef.fromJson(businessMap);
    final startsAt = JsonRead.utc(json['starts_at']) ?? DateTime.utc(1970);
    return Appointment(
      id: JsonRead.integer(json['id']),
      businessId: JsonRead.integerOrNull(json['business_id']) ?? business?.id,
      clientId: JsonRead.integerOrNull(json['client_id']),
      consumerId: JsonRead.integerOrNull(json['consumer_id']),
      staffId: JsonRead.integerOrNull(json['staff_id']) ?? JsonRead.integer(staff['id']),
      serviceId: JsonRead.integerOrNull(json['service_id']) ?? JsonRead.integer(service['id']),
      guests: JsonRead.integerOrNull(json['guests']),
      startsAt: startsAt,
      endsAt: JsonRead.utc(json['ends_at']) ?? startsAt,
      status: AppointmentStatus.fromWire(JsonRead.stringOrNull(json['status'])),
      source: JsonRead.nonEmptyOrNull(json['source']),
      depositTiyin: JsonRead.integerOrNull(json['deposit_tiyin']),
      paid: JsonRead.boolean(json['paid']),
      notes: JsonRead.stringOrNull(json['notes']),
      createdAt: JsonRead.unix(json['created_at']),
      updatedAt: JsonRead.unix(json['updated_at']),
      clientName: JsonRead.stringOrNull(json['client_name']),
      clientPhone: JsonRead.stringOrNull(json['client_phone']),
      serviceName: JsonRead.stringOrNull(json['service_name']) ?? JsonRead.stringOrNull(service['name']),
      serviceDuration:
          JsonRead.integerOrNull(json['service_duration']) ?? JsonRead.integerOrNull(service['duration_min']),
      servicePriceTiyin: JsonRead.integerOrNull(service['price_tiyin']),
      staffName: JsonRead.stringOrNull(json['staff_name']) ?? JsonRead.stringOrNull(staff['name']),
      items: JsonRead.list(json['items'], AppointmentItem.fromJson),
      business: business,
      canCancel: JsonRead.booleanOrNull(json['can_cancel']),
      canReview: JsonRead.booleanOrNull(json['can_review']),
      reviewId: JsonRead.integerOrNull(json['review_id']),
    );
  }

  final int id;

  /// business_id ?? business.id.
  final int? businessId;
  final int? clientId;
  final int? consumerId;

  /// staff_id ?? staff.id.
  final int staffId;

  /// service_id ?? service.id.
  final int serviceId;

  /// Rental.
  final int? guests;

  /// UTC 'Y-m-d H:i:s'; missing -> epoch 0 UTC.
  final DateTime startsAt;
  final DateTime endsAt;
  final AppointmentStatus status;

  /// admin|link|telegram|app.
  final String? source;
  final int? depositTiyin;

  /// 0/1/bool.
  final bool paid;
  final String? notes;

  /// Unix.
  final DateTime? createdAt;

  /// Unix.
  final DateTime? updatedAt;
  final String? clientName;
  final String? clientPhone;

  /// service_name ?? service.name.
  final String? serviceName;

  /// service_duration ?? service.duration_min.
  final int? serviceDuration;

  /// service.price_tiyin (consumer shape only).
  final int? servicePriceTiyin;

  /// staff_name ?? staff.name.
  final String? staffName;

  /// [] when missing.
  final List<AppointmentItem> items;

  /// Consumer shape.
  final BusinessRef? business;

  /// Consumer shape.
  final bool? canCancel;
  final bool? canReview;
  final int? reviewId;

  bool get requiresDeposit => (depositTiyin ?? 0) > 0 && !paid;
  Duration get duration => endsAt.difference(startsAt);

  /// timezone ?? business?.timezone ?? Asia/Tashkent.
  BizTime startLocal([String? timezone]) => Dates.toBizLocal(startsAt, timezone ?? business?.timezone);
  BizTime endLocal([String? timezone]) => Dates.toBizLocal(endsAt, timezone ?? business?.timezone);

  /// `reviewId` uses a sentinel so it can be set back to null.
  Appointment copyWith({
    AppointmentStatus? status,
    bool? paid,
    bool? canCancel,
    bool? canReview,
    Object? reviewId = _keep,
  }) =>
      Appointment(
        id: id,
        businessId: businessId,
        clientId: clientId,
        consumerId: consumerId,
        staffId: staffId,
        serviceId: serviceId,
        guests: guests,
        startsAt: startsAt,
        endsAt: endsAt,
        status: status ?? this.status,
        source: source,
        depositTiyin: depositTiyin,
        paid: paid ?? this.paid,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        clientName: clientName,
        clientPhone: clientPhone,
        serviceName: serviceName,
        serviceDuration: serviceDuration,
        servicePriceTiyin: servicePriceTiyin,
        staffName: staffName,
        items: items,
        business: business,
        canCancel: canCancel ?? this.canCancel,
        canReview: canReview ?? this.canReview,
        reviewId: identical(reviewId, _keep) ? this.reviewId : reviewId as int?,
      );

  /// Writes every flat key, plus 'business' (BusinessRef.toJson or null),
  /// 'service' {id, name, duration_min, price_tiyin} only when servicePriceTiyin != null,
  /// 'staff' {id, name} only when business != null (consumer shape), and
  /// can_cancel/can_review/review_id.
  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'client_id': clientId,
        'consumer_id': consumerId,
        'staff_id': staffId,
        'service_id': serviceId,
        'guests': guests,
        'starts_at': Dates.formatApiUtc(startsAt),
        'ends_at': Dates.formatApiUtc(endsAt),
        'status': status.wire,
        'source': source,
        'deposit_tiyin': depositTiyin,
        'paid': paid,
        'notes': notes,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
        'client_name': clientName,
        'client_phone': clientPhone,
        'service_name': serviceName,
        'service_duration': serviceDuration,
        'staff_name': staffName,
        'items': [for (final i in items) i.toJson()],
        'business': business?.toJson(),
        if (servicePriceTiyin != null)
          'service': {
            'id': serviceId,
            'name': serviceName,
            'duration_min': serviceDuration,
            'price_tiyin': servicePriceTiyin,
          },
        if (business != null) 'staff': {'id': staffId, 'name': staffName},
        'can_cancel': canCancel,
        'can_review': canReview,
        'review_id': reviewId,
      };
}

/// Appointment line (live AppointmentItem: all columns).
@immutable
final class AppointmentItem {
  const AppointmentItem({
    required this.id,
    this.businessId,
    this.appointmentId,
    this.kind = 'service',
    this.refId,
    required this.name,
    this.qty = 1,
    this.priceTiyin = 0,
    this.createdAt,
  });

  factory AppointmentItem.fromJson(Map<String, dynamic> json) => AppointmentItem(
        id: JsonRead.integer(json['id']),
        businessId: JsonRead.integerOrNull(json['business_id']),
        appointmentId: JsonRead.integerOrNull(json['appointment_id']),
        kind: JsonRead.nonEmptyOrNull(json['kind']) ?? 'service',
        refId: JsonRead.integerOrNull(json['ref_id']),
        name: JsonRead.string(json['name']),
        qty: JsonRead.integer(json['qty'], 1),
        priceTiyin: JsonRead.integer(json['price_tiyin']),
        createdAt: JsonRead.unix(json['created_at']),
      );

  final int id;
  final int? businessId;
  final int? appointmentId;

  /// 'service' | 'product'.
  final String kind;
  final int? refId;
  final String name;

  /// Default 1.
  final int qty;
  final int priceTiyin;
  final DateTime? createdAt;

  int get totalTiyin => qty * priceTiyin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'appointment_id': appointmentId,
        'kind': kind,
        'ref_id': refId,
        'name': name,
        'qty': qty,
        'price_tiyin': priceTiyin,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
      };
}
