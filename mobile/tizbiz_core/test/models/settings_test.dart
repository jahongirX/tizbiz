import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('live settings without NEW keys', () {
    final s = BookingSettings.fromJson(dataMap(settingsLiveJson));
    expect(s.isListed, isTrue);
    expect(s.lat, isNull);
    expect(s.address, isNull);
    expect(s.bookingLeadMin, 60);
    expect(s.telegramConnected, isFalse);
    expect(s.telegramWebhookOk, isNull);
    expectFixedPoint(s, (x) => x.toJson(), BookingSettings.fromJson);
  });

  test('diff', () {
    final s = BookingSettings.fromJson(dataMap(settingsNewJson));
    expectFixedPoint(s, (x) => x.toJson(), BookingSettings.fromJson);
    expect(s.diff(s), isEmpty);
    final edited = s.copyWith(tagline: 'X', mapUrl: null);
    expect(edited.diff(s), {'tagline': 'X', 'map_url': null});
    expect(s.copyWith(mapUrl: '').diff(s), {'map_url': null});
    expect(s.copyWith(lat: 41.3).diff(s), {'lat': 41.3});
    expect(s.copyWith(isListed: false, bookingHorizonDays: 60).diff(s), {'is_listed': false, 'booking_horizon_days': 60});
    final readOnly = BookingSettings.fromJson({...s.toJson(), 'rating_avg': 1.0, 'telegram_connected': false});
    expect(readOnly.diff(s), isEmpty);
    expect(BookingSettings.writableKeys, isNot(contains('rating_avg')));
    expect(s.copyWith().diff(s), isEmpty);
  });

  test('telegram token body', () {
    expect(BookingSettings.telegramTokenBody('123:abc'), {'telegram_bot_token': '123:abc'});
    expect(BookingSettings.telegramTokenBody(''), {'telegram_bot_token': ''});
  });
}
