import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';
import '../support/helpers.dart';

void main() {
  test('directory cards: float and decimal-string lat', () {
    final cards = dataList(directoryListJson).map(BusinessCard.fromJson).toList();
    expect(cards[0].lat, 41.2756);
    expect(cards[1].lat, 41.2756);
    expect(cards[1].lng, 69.2034);
    expect(cards[0].ratingAvg, 4.73);
    expect(cards[1].ratingAvg, 4.5);
    expect(cards[1].ratingCount, 2);
    expect(cards[1].isFeatured, isTrue);
    expect(cards[1].tagline, isNull);
    expect(cards[1].logo, isNull);
    expect(cards[1].priceFromTiyin, isNull);
    expect(cards[1].engine, Engine.catalog);
    expect(cards[0].hasLocation, isTrue);
    expect(cards[0].isFavorite, isTrue);
    final fav = cards[1].copyWith(isFavorite: true);
    expect(fav.isFavorite, isTrue);
    expect(fav.slug, 'aziza-tortlari');
    for (final c in cards) {
      expectFixedPoint(c, (x) => x.toJson(), BusinessCard.fromJson);
    }
  });

  test('detail page', () {
    final p = BusinessPage.fromJson(dataMap(directoryDetailJson));
    expect(p.business.hours.first.open, const HmTime(9, 0));
    expect(p.business.hours.first.close, const HmTime(21, 0));
    expect(p.business.hours.last.weekday, 7);
    expect(p.business.timezone, 'Asia/Tashkent');
    expect(p.business.telegramBotUsername, 'shoxbarber_bot');
    expect(p.business.card.slug, 'shox-barber');
    expect(p.reviewsPreview.length, 1);
    expect(p.rating.count, 15);
    expect(p.isFavorite, isFalse);
    final json = p.business.toJson();
    expect(json['phone'], '+998901111111');
    expect(json['slug'], 'shox-barber');
    expect(json['hours'], [
      {'weekday': 1, 'open': '09:00', 'close': '21:00'},
      {'weekday': 7, 'open': '10:00', 'close': '18:00'},
    ]);
    expectFixedPoint(p, (x) => x.toJson(), BusinessPage.fromJson);

    final fav = p.copyWith(isFavorite: true);
    expect(fav.isFavorite, isTrue);
    expect(fav.business.card.isFavorite, isTrue);
    expect(fav.business.phone, '+998901111111');
  });

  test('categories', () {
    final list = dataList(directoryCategoriesJson).map(Category.fromJson).toList();
    expect(list, hasLength(2));
    expect(list.first.key, 'barber');
    expect(list.first.icon, 'scissors');
    expect(list.last.engine, Engine.catalog);
    expect(list.last.labelRu, 'Кафе / Торты');
    for (final c in list) {
      expectFixedPoint(c, (x) => x.toJson(), Category.fromJson);
    }
  });

  test('BusinessRef and BusinessMembership', () {
    final ref = BusinessRef.fromJson(const {'id': 2, 'slug': 'shox-barber', 'name': 'Shox Barber', 'logo': ''});
    expect(ref.logo, isNull);
    expect(ref.timezone, isNull);
    expect(ref.engine, Engine.slot);
    expectFixedPoint(ref, (x) => x.toJson(), BusinessRef.fromJson);
    final m = BusinessMembership.fromJson(dataMap(loginJson)['businesses'][0] as Map<String, dynamic>);
    expect(m.role, BizRole.owner);
    expect(m.logo, 'https://api.tizbiz.uz/uploads/202609/a1b2.png');
    expectFixedPoint(m, (x) => x.toJson(), BusinessMembership.fromJson);
  });

  test('SiteBusiness defaults', () {
    final s = SiteBusiness.fromJson(const {'id': 1, 'name': 'X', 'slug': 'x'});
    expect(s.onlineBookingEnabled, isTrue);
    expect(s.timezone, 'Asia/Tashkent');
    expectFixedPoint(s, (x) => x.toJson(), SiteBusiness.fromJson);
  });
}
