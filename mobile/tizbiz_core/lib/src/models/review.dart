import 'package:meta/meta.dart';

import '../api/api_response.dart';
import '../time/dates.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'enums.dart';

const Object _keep = Object();

/// One class for ReviewPresenter::public (BP 4.4), ::mine (BP 4.6) and the business list (BP 4.7).
@immutable
final class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.authorName = '',
    this.serviceName,
    this.staffName,
    this.reply,
    this.repliedAt,
    this.createdAt,
    this.status,
    this.appointmentId,
    this.orderId,
    this.staffId,
    this.serviceId,
    this.business,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final business = JsonRead.objectOrNull(json['business']);
    final status = JsonRead.stringOrNull(json['status']);
    return Review(
      id: JsonRead.integer(json['id']),
      rating: JsonRead.integer(json['rating']),
      comment: JsonRead.stringOrNull(json['comment']),
      authorName: JsonRead.string(json['author_name']),
      serviceName: JsonRead.stringOrNull(json['service_name']),
      staffName: JsonRead.stringOrNull(json['staff_name']),
      reply: JsonRead.stringOrNull(json['reply']),
      repliedAt: JsonRead.unix(json['replied_at']),
      createdAt: JsonRead.unix(json['created_at']),
      status: status == null ? null : ReviewStatus.fromWire(status),
      appointmentId: JsonRead.integerOrNull(json['appointment_id']),
      orderId: JsonRead.integerOrNull(json['order_id']),
      staffId: JsonRead.integerOrNull(json['staff_id']),
      serviceId: JsonRead.integerOrNull(json['service_id']),
      business: business == null ? null : BusinessRef.fromJson(business),
    );
  }

  final int id;

  /// 1..5.
  final int rating;
  final String? comment;
  final String authorName;
  final String? serviceName;
  final String? staffName;
  final String? reply;

  /// Unix.
  final DateTime? repliedAt;

  /// Unix.
  final DateTime? createdAt;

  /// mine + business.
  final ReviewStatus? status;

  /// mine + business.
  final int? appointmentId;

  /// mine + business.
  final int? orderId;

  /// business.
  final int? staffId;

  /// business.
  final int? serviceId;

  /// {id, slug, name, logo} (mine).
  final BusinessRef? business;

  bool get hasReply => reply != null && reply!.isNotEmpty;

  /// `comment` uses a sentinel so it can be cleared to null.
  Review copyWith({String? reply, DateTime? repliedAt, int? rating, Object? comment = _keep}) => Review(
        id: id,
        rating: rating ?? this.rating,
        comment: identical(comment, _keep) ? this.comment : comment as String?,
        authorName: authorName,
        serviceName: serviceName,
        staffName: staffName,
        reply: reply ?? this.reply,
        repliedAt: repliedAt ?? this.repliedAt,
        createdAt: createdAt,
        status: status,
        appointmentId: appointmentId,
        orderId: orderId,
        staffId: staffId,
        serviceId: serviceId,
        business: business,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rating': rating,
        'comment': comment,
        'author_name': authorName,
        'service_name': serviceName,
        'staff_name': staffName,
        'reply': reply,
        'replied_at': repliedAt == null ? null : Dates.toUnix(repliedAt!),
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'status': status?.wire,
        'appointment_id': appointmentId,
        'order_id': orderId,
        'staff_id': staffId,
        'service_id': serviceId,
        'business': business?.toJson(),
      };
}

/// Detail `rating` {avg, count, distribution} and reviews list `meta` {avg, count, distribution}.
@immutable
final class RatingSummary {
  const RatingSummary({required this.avg, required this.count, required this.distribution});

  static const RatingSummary empty = RatingSummary(avg: 0, count: 0, distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0});

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['distribution'];
    final dist = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    if (raw is Map) {
      for (final e in raw.entries) {
        final stars = JsonRead.integerOrNull(e.key);
        if (stars != null && stars >= 1 && stars <= 5) dist[stars] = JsonRead.integer(e.value);
      }
    } else if (raw is List) {
      // PHP serialises a 0-indexed array as a list: index 0 = 1 star.
      for (var i = 0; i < raw.length && i < 5; i++) {
        dist[i + 1] = JsonRead.integer(raw[i]);
      }
    }
    return RatingSummary(
      avg: JsonRead.number(json['avg']),
      count: JsonRead.integer(json['count']),
      distribution: Map.unmodifiable(dist),
    );
  }

  /// Reads meta.extra.
  factory RatingSummary.fromMeta(PageMeta meta) => RatingSummary.fromJson(meta.extra);

  final double avg;
  final int count;

  /// {"1":0,...,"5":12} on the wire; always has keys 1..5 (missing -> 0).
  final Map<int, int> distribution;

  /// Share of [stars] in 0..1 (0 when count == 0), for the distribution bars.
  double share(int stars) => count <= 0 ? 0 : (distribution[stars] ?? 0) / count;

  /// {'avg', 'count', 'distribution': {'1': n, ... '5': n}}.
  Map<String, dynamic> toJson() => {
        'avg': avg,
        'count': count,
        'distribution': {for (var s = 1; s <= 5; s++) '$s': distribution[s] ?? 0},
      };
}
