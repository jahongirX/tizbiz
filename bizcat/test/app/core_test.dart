import 'package:bizcat/core/booking_flow.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/deposit.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/launcher.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/core/rental_pricing.dart';
import 'package:bizcat/data/directory_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fixtures.dart';

StorefrontData _site(Map<String, dynamic> env) => StorefrontData.fromJson(Fx.data(env));

void main() {
  group('booking flow', () {
    test('bookingFlowFor uses the payload shape', () {
      expect(bookingFlowFor(_site(Fx.siteSlot)), BookingFlow.slot);
      expect(bookingFlowFor(_site(Fx.siteCatalog)), BookingFlow.catalog);
      expect(bookingFlowFor(_site(Fx.siteRental)), BookingFlow.rental);
      expect(bookingFlowFor(_site(Fx.siteMedical)), BookingFlow.catalog);
      final medicalWithStaff = StorefrontData.fromJson({...Fx.data(Fx.siteSlot), 'engine': 'medical'});
      expect(bookingFlowFor(medicalWithStaff), BookingFlow.slot);
    });

    test('bookingFlowForEngine', () {
      expect(bookingFlowForEngine(Engine.slot), BookingFlow.slot);
      expect(bookingFlowForEngine(Engine.medical), BookingFlow.catalog);
      expect(bookingFlowForEngine(Engine.catalog), BookingFlow.catalog);
      expect(bookingFlowForEngine(Engine.rental), BookingFlow.rental);
    });

    test('bookingEntryPath + ctaLabelFor', () {
      expect(bookingEntryPath('shox-barber', BookingFlow.slot, serviceId: 11, staffId: 2), '/b/shox-barber/book?service=11&staff=2');
      expect(bookingEntryPath('serenada', BookingFlow.rental), '/b/serenada/rent');
      expect(bookingEntryPath('aziza-tortlari', BookingFlow.catalog), '/b/aziza-tortlari/menu');
      expect(ctaLabelFor(BookingFlow.slot, Engine.slot), 'Navbatga yozilish');
      expect(ctaLabelFor(BookingFlow.rental, Engine.rental), 'Sanani band qilish');
      expect(ctaLabelFor(BookingFlow.catalog, Engine.catalog), 'Buyurtma berish');
      expect(ctaLabelFor(BookingFlow.catalog, Engine.medical), 'Xizmatni tanlash');
    });
  });

  group('RentalPricing', () {
    test('prices, tables and limits', () {
      expect(RentalPricing.perGuestTiyin(RentalSession.morning), 1500000);
      expect(RentalPricing.perGuestTiyin(RentalSession.evening), 2500000);
      expect(RentalPricing.totalTiyin(RentalSession.evening, 180), 450000000);
      expect(Money.format(RentalPricing.totalTiyin(RentalSession.evening, 180)), Money.format(450000000));
      expect(RentalPricing.tables(100), 10);
      expect(RentalPricing.tables(101), 11);
      expect(RentalPricing.clampGuests(5), 30);
      expect(RentalPricing.clampGuests(5000), 1000);
      expect(RentalPricing.clampGuests(180), 180);
      expect(RentalPricing.title(RentalSession.morning), 'Ertalab');
      expect(RentalPricing.subtitle(RentalSession.evening), "Kechki to'y · 18:00–23:00");
      expect(RentalPricing.hours(RentalSession.morning), '10:00–16:00');
    });

    Appointment at(String start, String end) => Appointment(
          id: 1,
          staffId: 5,
          serviceId: 40,
          startsAt: Dates.parseUtc(start)!,
          endsAt: Dates.parseUtc(end)!,
        );

    test('sessionOf', () {
      expect(RentalPricing.sessionOf(at('2026-11-14 05:00:00', '2026-11-14 11:00:00'), 'Asia/Tashkent'), RentalSession.morning);
      expect(RentalPricing.sessionOf(at('2026-11-14 13:00:00', '2026-11-14 18:00:00'), 'Asia/Tashkent'), RentalSession.evening);
      expect(RentalPricing.sessionOf(at('2026-11-14 05:00:00', '2026-11-14 18:00:00'), 'Asia/Tashkent'), isNull);
    });
  });

  group('DirectoryQuery', () {
    test('toQuery drops blanks and trims q', () {
      const q = DirectoryQuery(q: '  soch ', category: '', city: 'Toshkent');
      expect(q.toQuery(), {'q': 'soch', 'city': 'Toshkent', 'sort': 'featured', 'page': 1, 'per_page': 20});
    });

    test('== / hashCode / copyWith with the sentinel', () {
      const a = DirectoryQuery(category: 'barber', city: 'Toshkent');
      expect(a, const DirectoryQuery(category: 'barber', city: 'Toshkent'));
      expect(a.hashCode, const DirectoryQuery(category: 'barber', city: 'Toshkent').hashCode);
      expect(a.copyWith(category: null).category, isNull);
      expect(a.copyWith(sort: 'rating').city, 'Toshkent');
      expect(a.copyWith(page: 2), isNot(a));
    });
  });

  group('launcher targets', () {
    test('precedence: mapUrl -> lat/lng -> name+address -> null', () {
      expect(mapTarget(mapUrl: 'https://yandex.uz/maps/-/CDabc', lat: 1, lng: 2).toString(), 'https://yandex.uz/maps/-/CDabc');
      expect(mapTarget(lat: 41.2756, lng: 69.2034).toString(), 'https://yandex.uz/maps/?pt=69.2034,41.2756&z=17&l=map');
      expect(mapTarget(name: 'Aziza Tortlari', address: 'Yunusobod 4-kvartal')?.queryParameters['q'],
          'Aziza Tortlari, Yunusobod 4-kvartal');
      expect(mapTarget(), isNull);
      expect(hasMapTarget(name: 'x'), isFalse);
    });
  });

  group('errors', () {
    test('errorText / isOffline', () {
      expect(errorText(const ApiException(kind: ApiErrorKind.http, status: 409, detail: 'Tanlangan vaqt band.')),
          'Tanlangan vaqt band.');
      expect(errorText(const DepositLaunchException(null)), "To'lov sahifasini ochib bo'lmadi.");
      expect(errorText(StateError('x')), 'Xatolik yuz berdi.');
      expect(isOffline(ApiException.network(ApiErrorKind.network)), isTrue);
      expect(isOffline(ApiException.network(ApiErrorKind.timeout)), isTrue);
      expect(isOffline(const ApiException(kind: ApiErrorKind.http, status: 500)), isFalse);
    });
  });

  group('AppPrefs', () {
    test('defaults, city, recent searches', () async {
      SharedPreferences.setMockInitialValues({});
      final p = AppPrefs(await SharedPreferences.getInstance());
      expect(p.onboarded, isFalse);
      expect(p.city, isNull);
      expect(p.cachedProfile, isNull);
      expect(p.recentSearches, isEmpty);
      await p.setOnboarded(true);
      await p.setCity('Termiz');
      expect(p.onboarded, isTrue);
      expect(p.city, 'Termiz');
      await p.setCity('');
      expect(p.city, isNull);
      for (final q in ['soch', 'a', 'Tort', 'SOCH', ' klinika ']) {
        await p.addRecentSearch(q);
      }
      expect(p.recentSearches, ['klinika', 'SOCH', 'Tort']);
      for (var i = 0; i < 10; i++) {
        await p.addRecentSearch('q$i');
      }
      expect(p.recentSearches.length, 8);
      expect(p.recentSearches.first, 'q9');
      await p.clearRecentSearches();
      expect(p.recentSearches, isEmpty);
    });

    test('cachedProfile round trip and garbage', () async {
      SharedPreferences.setMockInitialValues({AppPrefs.kProfile: '{not json'});
      final p = AppPrefs(await SharedPreferences.getInstance());
      expect(p.cachedProfile, isNull);
      await p.setCachedProfile(ConsumerUser.fromJson(Fx.data(Fx.me)));
      expect(p.cachedProfile?.name, 'Aziza Karimova');
      expect(p.cachedProfile?.stats?.reviewsTotal, 3);
      await p.setCachedProfile(null);
      expect(p.cachedProfile, isNull);
    });
  });

  test('cities', () {
    expect(kCities, ['Termiz', 'Toshkent']);
    expect(cityLabel(null), 'Barcha shaharlar');
    expect(cityLabel('Termiz'), 'Termiz');
  });
}
