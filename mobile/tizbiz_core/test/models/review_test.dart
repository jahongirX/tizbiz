import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('public item', () {
    final r = Review.fromJson(dataList(directoryReviewsJson).single);
    expect(r.rating, 5);
    expect(r.authorName, 'Aziza K.');
    expect(r.repliedAt, Dates.fromUnix(1791636000));
    expect(r.hasReply, isTrue);
    expect(r.status, isNull);
    expect(r.business, isNull);
    expectFixedPoint(r, (x) => x.toJson(), Review.fromJson);
  });

  test('mine item with business', () {
    final r = Review.fromJson(dataList(consumerReviewsJson).single);
    expect(r.business?.slug, 'shox-barber');
    expect(r.appointmentId, 4990);
    expect(r.orderId, isNull);
    expect(r.status, ReviewStatus.published);
    expect(r.hasReply, isFalse);
    expectFixedPoint(r, (x) => x.toJson(), Review.fromJson);
    final edited = r.copyWith(rating: 4, comment: null);
    expect(edited.rating, 4);
    expect(edited.comment, isNull);
    expect(r.copyWith(rating: 3).comment, r.comment);
  });

  test('business item with staff_id', () {
    final r = Review.fromJson(dataList(businessReviewsJson).single);
    expect(r.staffId, 2);
    expect(r.serviceId, 11);
    expect(r.reply, isNull);
    final replied = r.copyWith(reply: 'Rahmat!', repliedAt: DateTime.utc(2026, 10, 17));
    expect(replied.hasReply, isTrue);
    expect(replied.repliedAt, DateTime.utc(2026, 10, 17));
    expectFixedPoint(r, (x) => x.toJson(), Review.fromJson);
    expectFixedPoint(replied, (x) => x.toJson(), Review.fromJson);
  });

  test('RatingSummary', () {
    final s = RatingSummary.fromJson(const {
      'avg': 4.73,
      'count': 15,
      'distribution': {'1': 0, '3': 1, '4': 2, '5': 12},
    });
    expect(s.distribution[2], 0);
    expect(s.distribution.keys, containsAll([1, 2, 3, 4, 5]));
    expect(s.share(5), closeTo(0.8, 1e-9));
    expect(RatingSummary.empty.share(5), 0);
    expect(s.toJson()['distribution'], {'1': 0, '2': 0, '3': 1, '4': 2, '5': 12});
    expectFixedPoint(s, (x) => x.toJson(), RatingSummary.fromJson);
    final meta = PageMeta.fromJson(metaMap(businessReviewsJson));
    expect(RatingSummary.fromMeta(meta).count, 15);
    expect(RatingSummary.fromMeta(meta).distribution[5], 12);
  });
}
