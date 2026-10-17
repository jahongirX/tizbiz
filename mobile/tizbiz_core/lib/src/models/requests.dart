import 'package:meta/meta.dart';

import '../format/phone.dart';
import '../time/dates.dart';
import '../time/hm_time.dart';
import '../time/local_date.dart';
import 'enums.dart';
import 'schedule.dart';

/// POST /v1/consumer/appointments (BP 4.6). Use with idempotencyKey. `toJson` omits null keys.
@immutable
final class ConsumerBookingRequest {
  /// {"staff_id","service_id","starts_at":'Y-m-d H:i:s' UTC,"notes"?,"name"?}
  const ConsumerBookingRequest.slot({
    required this.staffId,
    required this.serviceId,
    required DateTime this.startsAt,
    this.notes,
    this.name,
  })  : date = null,
        session = null,
        guests = null;

  /// {"staff_id","service_id","date":'YYYY-MM-DD',"session"?: 'morning'|'evening'
  /// (null = full day),"guests"?,"notes"?,"name"?}
  const ConsumerBookingRequest.rental({
    required this.staffId,
    required this.serviceId,
    required LocalDate this.date,
    this.session,
    this.guests,
    this.notes,
    this.name,
  }) : startsAt = null;

  final int staffId;
  final int serviceId;
  final DateTime? startsAt;
  final LocalDate? date;
  final RentalSession? session;
  final int? guests;
  final String? notes;
  final String? name;

  bool get isRental => date != null;

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'service_id': serviceId,
        if (startsAt != null) 'starts_at': Dates.formatApiUtc(startsAt!),
        if (date != null) 'date': date!.toIso(),
        if (session != null) 'session': session!.wire,
        if (guests != null) 'guests': guests,
        if (notes != null) 'notes': notes,
        if (name != null) 'name': name,
      };
}

/// POST /v1/appointments with an owner/admin token (admin mode; no slot check).
/// {"staff_id","service_id","starts_at" | "date"+"session","guests"?,
/// "client_id"? | "client":{"phone" (normalized),"name"},"notes"?,"status"?}
@immutable
final class AdminBookingRequest {
  const AdminBookingRequest({
    required this.staffId,
    required this.serviceId,
    this.startsAt,
    this.date,
    this.session,
    this.guests,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.notes,
    this.status,
  })  : assert(startsAt != null || date != null, 'startsAt or date is required'),
        assert(clientId != null || clientPhone != null, 'clientId or clientPhone is required');

  final int staffId;
  final int serviceId;
  final DateTime? startsAt;
  final LocalDate? date;
  final RentalSession? session;
  final int? guests;
  final int? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? notes;
  final AppointmentStatus? status;

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'service_id': serviceId,
        if (startsAt != null) 'starts_at': Dates.formatApiUtc(startsAt!),
        if (startsAt == null && date != null) 'date': date!.toIso(),
        if (startsAt == null && session != null) 'session': session!.wire,
        if (guests != null) 'guests': guests,
        if (clientId != null)
          'client_id': clientId
        else if (clientPhone != null)
          'client': {
            'phone': Phone.normalize(clientPhone) ?? clientPhone!.trim(),
            if (clientName != null) 'name': clientName,
          },
        if (notes != null) 'notes': notes,
        if (status != null) 'status': status!.wire,
      };
}

/// POST /v1/consumer/orders: {"slug","items":[{"service_id","qty"}],"note"?,"name"?}
@immutable
final class ConsumerOrderRequest {
  const ConsumerOrderRequest({required this.slug, required this.items, this.note, this.name});

  final String slug;
  final List<OrderLine> items;
  final String? note;
  final String? name;

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'items': [for (final i in items) i.toJson()],
        if (note != null) 'note': note,
        if (name != null) 'name': name,
      };
}

/// {"service_id","qty"}
@immutable
final class OrderLine {
  const OrderLine(this.serviceId, this.qty);

  final int serviceId;
  final int qty;

  Map<String, dynamic> toJson() => {'service_id': serviceId, 'qty': qty};
}

/// POST /v1/consumer/reviews: exactly one of appointmentId / orderId (asserted).
/// PATCH /v1/consumer/reviews/{id}: use toPatchJson() -> {"rating","comment"}.
@immutable
final class ReviewInput {
  const ReviewInput({this.appointmentId, this.orderId, required this.rating, this.comment})
      : assert((appointmentId == null) != (orderId == null), 'Exactly one of appointmentId / orderId');

  final int? appointmentId;
  final int? orderId;
  final int rating;
  final String? comment;

  Map<String, dynamic> toJson() => {
        if (appointmentId != null) 'appointment_id': appointmentId,
        if (orderId != null) 'order_id': orderId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      };

  Map<String, dynamic> toPatchJson() => {'rating': rating, 'comment': comment};
}

/// PATCH /v1/consumer/me: any subset of name, birthday ('Y-m-d'), gender, city, locale.
@immutable
final class ConsumerProfilePatch {
  const ConsumerProfilePatch({this.name, this.birthday, this.gender, this.city, this.locale});

  final String? name;
  final LocalDate? birthday;
  final Gender? gender;
  final String? city;
  final String? locale;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (birthday != null) 'birthday': birthday!.toIso(),
        if (gender != null) 'gender': gender!.wire,
        if (city != null) 'city': city,
        if (locale != null) 'locale': locale,
      };
}

/// POST /v1/team: {"phone" (normalized),"name","role","password"?,"staff_id"?}
@immutable
final class TeamMemberInput {
  const TeamMemberInput({required this.phone, required this.name, required this.role, this.password, this.staffId});

  final String phone;
  final String name;
  final BizRole role;
  final String? password;
  final int? staffId;

  Map<String, dynamic> toJson() => {
        'phone': Phone.normalize(phone) ?? phone.trim(),
        'name': name,
        'role': role.wire,
        if (password != null) 'password': password,
        if (staffId != null) 'staff_id': staffId,
      };
}

/// PATCH /v1/team/{userId}: {"role"?, "staff_id"?}. unlinkStaff:true sends "staff_id": null
/// explicitly.
@immutable
final class TeamMemberPatch {
  const TeamMemberPatch({this.role, this.staffId, this.unlinkStaff = false});

  final BizRole? role;
  final int? staffId;
  final bool unlinkStaff;

  Map<String, dynamic> toJson() => {
        if (role != null) 'role': role!.wire,
        if (unlinkStaff)
          'staff_id': null
        else if (staffId != null)
          'staff_id': staffId,
      };
}

/// POST /v1/staff/{id}/time-off: {"date","start_time"?,"end_time"?,"reason"?} (times as 'HH:MM:SS').
@immutable
final class TimeOffInput {
  const TimeOffInput({required this.date, this.start, this.end, this.reason});

  final LocalDate date;
  final HmTime? start;
  final HmTime? end;
  final String? reason;

  Map<String, dynamic> toJson() => {
        'date': date.toIso(),
        if (start != null) 'start_time': start!.toWire(),
        if (end != null) 'end_time': end!.toWire(),
        if (reason != null) 'reason': reason,
      };
}

/// PUT /v1/staff/{id}/working-hours:
/// {"items":[{"weekday":1..7,"start_time":"09:00:00","end_time":"18:00:00"}]}.
/// Replaces the whole week; days without an entry are days off. NEVER the web's {days:[...]} shape.
@immutable
final class WorkingHoursInput {
  const WorkingHoursInput(this.days);

  final List<WorkingHours> days;

  Map<String, dynamic> toJson() => {
        'items': [
          for (final d in days) {'weekday': d.weekday, 'start_time': d.start.toWire(), 'end_time': d.end.toWire()},
        ],
      };
}
