import 'package:meta/meta.dart';

import '../time/dates.dart';
import '../util/json_read.dart';
import 'business.dart';
import 'enums.dart';

const Object _keep = Object();

/// Order::fields() (live: id, status, total_tiyin, customer_name, customer_phone, note, source,
/// created_at, items, items_count) + consumer extras (BP 4.6: business, can_cancel, can_review,
/// review_id).
@immutable
final class Order {
  const Order({
    required this.id,
    this.status = OrderStatus.unknown,
    this.totalTiyin = 0,
    this.customerName,
    this.customerPhone,
    this.note,
    this.source,
    this.createdAt,
    this.items = const [],
    this.itemsCount = 0,
    this.business,
    this.canCancel,
    this.canReview,
    this.reviewId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final items = JsonRead.list(json['items'], OrderItem.fromJson);
    final business = JsonRead.objectOrNull(json['business']);
    return Order(
      id: JsonRead.integer(json['id']),
      status: OrderStatus.fromWire(JsonRead.stringOrNull(json['status'])),
      totalTiyin: JsonRead.integer(json['total_tiyin']),
      customerName: JsonRead.stringOrNull(json['customer_name']),
      customerPhone: JsonRead.stringOrNull(json['customer_phone']),
      note: JsonRead.stringOrNull(json['note']),
      source: JsonRead.nonEmptyOrNull(json['source']),
      createdAt: JsonRead.unix(json['created_at']),
      items: items,
      itemsCount: JsonRead.integerOrNull(json['items_count']) ?? items.length,
      business: business == null ? null : BusinessRef.fromJson(business),
      canCancel: JsonRead.booleanOrNull(json['can_cancel']),
      canReview: JsonRead.booleanOrNull(json['can_review']),
      reviewId: JsonRead.integerOrNull(json['review_id']),
    );
  }

  final int id;
  final OrderStatus status;
  final int totalTiyin;
  final String? customerName;
  final String? customerPhone;
  final String? note;

  /// site|bot|admin|app.
  final String? source;

  /// Unix.
  final DateTime? createdAt;
  final List<OrderItem> items;

  /// Fallback items.length.
  final int itemsCount;

  /// Consumer only.
  final BusinessRef? business;
  final bool? canCancel;
  final bool? canReview;
  final int? reviewId;

  /// `reviewId` uses a sentinel so it can be set back to null.
  Order copyWith({OrderStatus? status, bool? canCancel, bool? canReview, Object? reviewId = _keep}) => Order(
        id: id,
        status: status ?? this.status,
        totalTiyin: totalTiyin,
        customerName: customerName,
        customerPhone: customerPhone,
        note: note,
        source: source,
        createdAt: createdAt,
        items: items,
        itemsCount: itemsCount,
        business: business,
        canCancel: canCancel ?? this.canCancel,
        canReview: canReview ?? this.canReview,
        reviewId: identical(reviewId, _keep) ? this.reviewId : reviewId as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.wire,
        'total_tiyin': totalTiyin,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'note': note,
        'source': source,
        'created_at': createdAt == null ? null : Dates.toUnix(createdAt!),
        'items': [for (final i in items) i.toJson()],
        'items_count': itemsCount,
        'business': business?.toJson(),
        'can_cancel': canCancel,
        'can_review': canReview,
        'review_id': reviewId,
      };
}

@immutable
final class OrderItem {
  const OrderItem({required this.id, this.serviceId, required this.name, this.priceTiyin = 0, this.qty = 1});

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: JsonRead.integer(json['id']),
        serviceId: JsonRead.integerOrNull(json['service_id']),
        name: JsonRead.string(json['name']),
        priceTiyin: JsonRead.integer(json['price_tiyin']),
        qty: JsonRead.integer(json['qty'], 1),
      );

  final int id;
  final int? serviceId;
  final String name;
  final int priceTiyin;
  final int qty;

  int get totalTiyin => qty * priceTiyin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_id': serviceId,
        'name': name,
        'price_tiyin': priceTiyin,
        'qty': qty,
      };
}
