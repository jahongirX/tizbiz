import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('verify', () {
    final s = ConsumerSession.fromJson(dataMap(verifyJson));
    expect(s.token, 'eyJ...');
    expect(s.isNew, isFalse);
    expect(s.expiresAt, Dates.fromUnix(1794805920));
    expect(s.consumer.gender, Gender.female);
    expect(s.consumer.birthday, isNull);
    expect(s.consumer.stats, isNull);
    expect(s.consumer.locale, 'uz');
    expectFixedPoint(s, (x) => x.toJson(), ConsumerSession.fromJson);
  });

  test('GET me with stats', () {
    final u = ConsumerUser.fromJson(dataMap(consumerMeJson));
    expect(u.stats?.favoritesTotal, 2);
    expect(u.stats?.appointmentsUpcoming, 1);
    expect(u.birthday, const LocalDate(1996, 4, 12));
    expect(u.displayName, 'Aziza Karimova');
    expectFixedPoint(u, (x) => x.toJson(), ConsumerUser.fromJson);
    final anon = ConsumerUser.fromJson(const {'id': 1, 'phone': '+998900000001', 'name': null});
    expect(anon.displayName, '+998 90 000 00 01');
  });

  test('OtpSent', () {
    final o = OtpSent.fromJson(dataMap(otpJson));
    expect(o.sent, isTrue);
    expect(o.ttlSec, 120);
    expect(o.retryAfterSec, 60);
    expectFixedPoint(o, (x) => x.toJson(), OtpSent.fromJson);
  });

  test('loyalty wallet', () {
    final e = LoyaltyWalletEntry.fromJson(dataList(loyaltyJson).single);
    expect(e.cashbackTiyin, 1500000);
    expect(e.points, 120);
    expect(e.visits, 5);
    expect(e.business.brandColor, '#1E1B4B');
    expectFixedPoint(e, (x) => x.toJson(), LoyaltyWalletEntry.fromJson);
  });
}
