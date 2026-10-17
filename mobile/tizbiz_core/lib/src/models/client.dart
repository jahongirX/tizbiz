import 'package:meta/meta.dart';

import '../format/phone.dart';
import '../time/dates.dart';
import '../time/local_date.dart';
import '../util/json_read.dart';
import 'appointment.dart';

/// GET /v1/clients rows (live: id, name, phone, email, birthday, tags, created_at, visits,
/// spent_tiyin, last_visit, categories) and GET /v1/clients/{id} -> client (all columns:
/// + business_id, notes, updated_at). Owner/admin only.
@immutable
final class Client {
  const Client({
    required this.id,
    this.businessId,
    required this.name,
    required this.phone,
    this.email,
    this.birthday,
    this.notes,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
    this.visits,
    this.spentTiyin,
    this.lastVisit,
    this.categories = const [],
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: JsonRead.integer(json['id']),
        businessId: JsonRead.integerOrNull(json['business_id']),
        name: JsonRead.string(json['name']),
        phone: JsonRead.string(json['phone']),
        email: JsonRead.nonEmptyOrNull(json['email']),
        birthday: JsonRead.date(json['birthday']),
        notes: JsonRead.stringOrNull(json['notes']),
        tags: JsonRead.stringList(json['tags']),
        createdAt: JsonRead.unix(json['created_at']),
        updatedAt: JsonRead.unix(json['updated_at']),
        visits: JsonRead.integerOrNull(json['visits']),
        spentTiyin: JsonRead.integerOrNull(json['spent_tiyin']),
        lastVisit: JsonRead.utc(json['last_visit']),
        categories: JsonRead.list(json['categories'], ClientCategory.fromJson),
      );

  final int id;
  final int? businessId;
  final String name;
  final String phone;
  final String? email;

  /// 'Y-m-d'.
  final LocalDate? birthday;
  final String? notes;

  /// Array or JSON string on the wire.
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// List only.
  final int? visits;

  /// List only.
  final int? spentTiyin;

  /// UTC 'Y-m-d H:i:s', list only.
  final DateTime? lastVisit;

  /// List only; [] otherwise.
  final List<ClientCategory> categories;

  /// Body for POST/PATCH /v1/clients: name, phone (normalized), email, birthday, notes, tags.
  Map<String, dynamic> toInput() => {
        'name': name,
        'phone': Phone.normalize(phone) ?? phone,
        'email': email,
        'birthday': birthday?.toIso(),
        'notes': notes,
        'tags': tags,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'business_id': businessId,
        'name': name,
        'phone': phone,
        'email': email,
        'birthday': birthday?.toIso(),
        'notes': notes,
        'tags': tags,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'updated_at': updatedAt == null ? null : Dates.toUnix(updatedAt!),
        'visits': visits,
        'spent_tiyin': spentTiyin,
        'last_visit': lastVisit == null ? null : Dates.formatApiUtc(lastVisit!),
        'categories': [for (final c in categories) c.toJson()],
      };
}

@immutable
final class ClientCategory {
  const ClientCategory({required this.id, required this.name, this.color, this.sort});

  factory ClientCategory.fromJson(Map<String, dynamic> json) => ClientCategory(
        id: JsonRead.integer(json['id']),
        name: JsonRead.string(json['name']),
        color: JsonRead.nonEmptyOrNull(json['color']),
        sort: JsonRead.integerOrNull(json['sort']),
      );

  final int id;
  final String name;

  /// '#hex'.
  final String? color;

  /// client-categories index only.
  final int? sort;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'sort': sort};
}

@immutable
final class ClientLoyalty {
  const ClientLoyalty({this.points = 0, this.cashbackTiyin = 0});

  factory ClientLoyalty.fromJson(Map<String, dynamic> json) => ClientLoyalty(
        points: JsonRead.integer(json['points']),
        cashbackTiyin: JsonRead.integer(json['cashback_tiyin']),
      );

  final int points;
  final int cashbackTiyin;

  Map<String, dynamic> toJson() => {'points': points, 'cashback_tiyin': cashbackTiyin};
}

/// GET /v1/clients/{id}.
@immutable
final class ClientDetail {
  const ClientDetail({required this.client, this.categories = const [], this.history = const [], this.loyalty});

  factory ClientDetail.fromJson(Map<String, dynamic> json) {
    final loyalty = JsonRead.objectOrNull(json['loyalty']);
    return ClientDetail(
      client: Client.fromJson(JsonRead.objectOrNull(json['client']) ?? const <String, dynamic>{}),
      categories: JsonRead.list(json['categories'], ClientCategory.fromJson),
      history: JsonRead.list(json['history'], Appointment.fromJson),
      loyalty: loyalty == null ? null : ClientLoyalty.fromJson(loyalty),
    );
  }

  final Client client;
  final List<ClientCategory> categories;

  /// Last 20.
  final List<Appointment> history;

  /// Optional.
  final ClientLoyalty? loyalty;

  Map<String, dynamic> toJson() => {
        'client': client.toJson(),
        'categories': [for (final c in categories) c.toJson()],
        'history': [for (final a in history) a.toJson()],
        'loyalty': loyalty?.toJson(),
      };
}
