import 'package:bizcat/app/app.dart';
import 'package:bizcat/app/router.dart';
import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/api.dart';
import 'package:bizcat/core/images.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/auth/login_name_screen.dart';
import 'package:bizcat/features/auth/login_phone_screen.dart';
import 'package:bizcat/features/auth/otp_code_screen.dart';
import 'package:bizcat/features/booking_catalog/cart_screen.dart';
import 'package:bizcat/features/booking_catalog/menu_screen.dart';
import 'package:bizcat/features/booking_rental/rental_booking_screen.dart';
import 'package:bizcat/features/booking_slot/slot_booking_screen.dart';
import 'package:bizcat/features/bookings/appointment_detail_screen.dart';
import 'package:bizcat/features/bookings/my_bookings_screen.dart';
import 'package:bizcat/features/bookings/order_detail_screen.dart';
import 'package:bizcat/features/business/business_reviews_screen.dart';
import 'package:bizcat/features/business/business_screen.dart';
import 'package:bizcat/features/directory/directory_screen.dart';
import 'package:bizcat/features/favorites/favorites_screen.dart';
import 'package:bizcat/features/home/home_screen.dart';
import 'package:bizcat/features/loyalty/loyalty_wallet_screen.dart';
import 'package:bizcat/features/onboarding/city_picker_screen.dart';
import 'package:bizcat/features/onboarding/onboarding_screen.dart';
import 'package:bizcat/features/onboarding/splash_screen.dart';
import 'package:bizcat/features/profile/profile_edit_screen.dart';
import 'package:bizcat/features/profile/profile_screen.dart';
import 'package:bizcat/features/reviews/my_reviews_screen.dart';
import 'package:bizcat/features/reviews/review_compose_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

import '../support/fake_api.dart';
import '../support/pump.dart';

void main() {
  group('routeRequiresAuth', () {
    const table = <String, bool>{
      '/splash': false,
      '/onboarding': false,
      '/city': false,
      '/login': false,
      '/login/code?phone=%2B998900000001': false,
      '/login/name': true,
      '/home': false,
      '/explore?q=soch': false,
      '/bookings': false,
      '/bookings?tab=orders': false,
      '/bookings/a/5012': true,
      '/bookings/a/5012?new=1': true,
      '/bookings/o/702': true,
      '/bookings/a/abc': false,
      '/favorites': false,
      '/profile': false,
      '/profile/edit': true,
      '/profile/wallet': true,
      '/profile/reviews': true,
      '/b/shox-barber': false,
      '/b/shox-barber/reviews': false,
      '/b/shox-barber/book': true,
      '/b/shox-barber/book?service=11&staff=2': true,
      '/b/serenada/rent': true,
      '/b/aziza-tortlari/menu': false,
      '/b/aziza-tortlari/cart': false,
      '/b/aziza-tortlari/checkout': true,
      '/review/new?appointment=4990': true,
      '/review/88/edit': true,
      '/': false,
    };
    for (final e in table.entries) {
      test('${e.key} -> ${e.value}', () => expect(routeRequiresAuth(Uri.parse(e.key)), e.value));
    }
  });

  group('AppRoutes builders', () {
    test('encode and omit empty values', () {
      expect(AppRoutes.loginWith(from: '/b/x/book', expired: true), '/login?from=%2Fb%2Fx%2Fbook&expired=1');
      expect(AppRoutes.loginWith(), '/login');
      expect(AppRoutes.loginCodeWith(phone: '+998900000001'), '/login/code?phone=%2B998900000001');
      expect(AppRoutes.exploreWith(category: 'barber'), '/explore?category=barber');
      expect(AppRoutes.exploreWith(q: '', focus: true), '/explore?focus=1');
      expect(AppRoutes.bookingsWith(), '/bookings');
      expect(AppRoutes.bookingsWith(tab: 'orders'), '/bookings?tab=orders');
      expect(AppRoutes.business('shox-barber', tab: 'reviews'), '/b/shox-barber?tab=reviews');
      expect(AppRoutes.bookSlot('shox-barber', serviceId: 11, staffId: 2), '/b/shox-barber/book?service=11&staff=2');
      expect(AppRoutes.menu('aziza-tortlari', reorder: 690), '/b/aziza-tortlari/menu?reorder=690');
      expect(AppRoutes.appointment(5012, created: true), '/bookings/a/5012?new=1');
      expect(AppRoutes.order(702), '/bookings/o/702');
      expect(AppRoutes.reviewNew(appointmentId: 4990, businessName: 'Shox Barber'),
          '/review/new?appointment=4990&bname=Shox+Barber');
      expect(AppRoutes.reviewEdit(88), '/review/88/edit');
    });

    test('safeFrom', () {
      expect(safeFrom('/b/x/book'), '/b/x/book');
      expect(safeFrom('/login?from=x'), isNull);
      expect(safeFrom('/splash'), isNull);
      expect(safeFrom('https://evil.example'), isNull);
      expect(safeFrom('//evil.example'), isNull);
      expect(safeFrom(null), isNull);
    });
  });

  group('appRedirect', () {
    final signedIn = const SessionSignedIn(ConsumerUser(id: 17, phone: '+998900000001'));
    String? r(String loc, SessionState s, {bool onboarded = true}) =>
        appRedirect(Uri.parse(loc), session: s, onboarded: onboarded);

    test('rules in order', () {
      expect(r('/', const SessionSignedOut()), '/home');
      expect(r('/b/x/book', const SessionUnknown()), '/splash?from=%2Fb%2Fx%2Fbook');
      expect(r('/splash', const SessionUnknown()), isNull);
      expect(r('/splash?from=%2Fb%2Fx', const SessionSignedOut(), onboarded: false), '/onboarding?from=%2Fb%2Fx');
      expect(r('/splash?from=%2Flogin', const SessionSignedOut()), '/home');
      expect(r('/splash', signedIn), '/home');
      expect(r('/profile/wallet', const SessionSignedOut(SignOutReason.expired)),
          '/login?from=%2Fprofile%2Fwallet&expired=1');
      expect(r('/login?from=%2Fb%2Fx%2Fbook', signedIn), '/b/x/book');
      expect(r('/login/code?phone=1', signedIn), '/home');
      expect(r('/login/name', signedIn), isNull);
      expect(r('/login/code', const SessionSignedOut()), '/login');
      expect(r('/home', const SessionSignedOut()), isNull);
    });
  });

  group('every route opens its screen', () {
    const signedInRoutes = <String, Type>{
      '/onboarding': OnboardingScreen,
      '/city': CityPickerScreen,
      '/login/name': LoginNameScreen,
      '/home': HomeScreen,
      '/explore': DirectoryScreen,
      '/bookings': MyBookingsScreen,
      '/bookings/a/5012': AppointmentDetailScreen,
      '/bookings/o/702': OrderDetailScreen,
      '/favorites': FavoritesScreen,
      '/profile': ProfileScreen,
      '/profile/edit': ProfileEditScreen,
      '/profile/wallet': LoyaltyWalletScreen,
      '/profile/reviews': MyReviewsScreen,
      '/b/shox-barber': BusinessScreen,
      '/b/shox-barber/reviews': BusinessReviewsScreen,
      '/b/shox-barber/book?service=11&staff=2': SlotBookingScreen,
      '/b/serenada/rent': RentalBookingScreen,
      '/b/aziza-tortlari/menu': MenuScreen,
      '/b/aziza-tortlari/cart': CartScreen,
      '/review/new?appointment=4990': ReviewComposeScreen,
      '/review/88/edit': ReviewComposeScreen,
    };
    for (final e in signedInRoutes.entries) {
      testWidgets('${e.key} (signed in)', (t) async {
        final h = await pumpBizcat(t, location: e.key, signedIn: true);
        expect(h.location, e.key);
        expect(find.byType(e.value), findsOneWidget);
        await _drain(t);
      });
    }

    testWidgets('checkout with an empty cart goes back to the menu', (t) async {
      final h = await pumpBizcat(t, location: '/b/aziza-tortlari/checkout', signedIn: true);
      expect(h.location, '/b/aziza-tortlari/menu');
      expect(find.byType(MenuScreen), findsOneWidget);
      await _drain(t);
    });

    const signedOutRoutes = <String, Type>{
      '/login': LoginPhoneScreen,
      '/login/code?phone=%2B998900000001': OtpCodeScreen,
      '/home': HomeScreen,
      '/b/shox-barber': BusinessScreen,
    };
    for (final e in signedOutRoutes.entries) {
      testWidgets('${e.key} (signed out)', (t) async {
        final h = await pumpBizcat(t, location: e.key);
        expect(h.location, e.key);
        expect(find.byType(e.value), findsOneWidget);
        await _drain(t);
      });
    }

    testWidgets('route params reach the screens', (t) async {
      await pumpBizcat(t, location: '/b/shox-barber/book?service=11&staff=2', signedIn: true);
      final w = t.widget<SlotBookingScreen>(find.byType(SlotBookingScreen));
      expect(w.slug, 'shox-barber');
      expect(w.serviceId, 11);
      expect(w.staffId, 2);
      await _drain(t);
    });

    testWidgets('a bad optional int is null', (t) async {
      await pumpBizcat(t, location: '/b/shox-barber/book?service=x', signedIn: true);
      expect(t.widget<SlotBookingScreen>(find.byType(SlotBookingScreen)).serviceId, isNull);
      await _drain(t);
    });

    testWidgets('the splash shows while the session is unknown', (t) async {
      SharedPreferences.setMockInitialValues({'bizcat.onboarded': true});
      final sp = await SharedPreferences.getInstance();
      final api = FakeApi()..on('GET', '/v1/consumer/me', body: const {'data': {'id': 17, 'phone': '+998900000001'}});
      await t.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [
          prefsProvider.overrideWithValue(sp),
          apiProvider.overrideWith((ref) => api.client(token: fakeConsumerToken())),
          netImagesEnabledProvider.overrideWithValue(false),
        ],
        child: const BizcatApp(googleFonts: false),
      ));
      expect(find.byType(SplashScreen), findsOneWidget);
      await settle(t);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('redirects', () {
    testWidgets('signed out /profile/wallet -> login with from', (t) async {
      final h = await pumpBizcat(t, location: '/profile/wallet');
      expect(h.location, '/login?from=%2Fprofile%2Fwallet');
      expect(find.byType(LoginPhoneScreen), findsOneWidget);
    });

    testWidgets('signed in /login -> /home', (t) async {
      final h = await pumpBizcat(t, location: '/login', signedIn: true);
      expect(h.location, '/home');
    });

    testWidgets('signed in /login?from=... -> from', (t) async {
      final h = await pumpBizcat(t, location: '/login?from=%2Fb%2Fshox-barber', signedIn: true);
      expect(h.location, '/b/shox-barber');
    });

    testWidgets('first run cold start -> /onboarding', (t) async {
      final h = await pumpBizcat(t, location: AppRoutes.splash, deepLink: true, prefs: {'bizcat.onboarded': false});
      expect(h.location, '/onboarding');
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('first run deep link keeps from through onboarding', (t) async {
      final h = await pumpBizcat(t, location: '/b/shox-barber', deepLink: true, prefs: {'bizcat.onboarded': false});
      expect(h.location, '/onboarding?from=%2Fb%2Fshox-barber');
      expect(t.widget<OnboardingScreen>(find.byType(OnboardingScreen)).from, '/b/shox-barber');
    });

    testWidgets('/b/x/book deep link with a valid session stays after the splash', (t) async {
      final h = await pumpBizcat(t, location: '/b/x/book', deepLink: true, signedIn: true);
      expect(h.location, '/b/x/book');
      expect(find.byType(SlotBookingScreen), findsOneWidget);
    });

    testWidgets('/b/x/book deep link signed out -> login with from', (t) async {
      final h = await pumpBizcat(t, location: '/b/x/book', deepLink: true);
      expect(h.location, '/login?from=%2Fb%2Fx%2Fbook');
    });

    testWidgets('a bad id shows Sahifa topilmadi', (t) async {
      await pumpBizcat(t, location: '/bookings/a/abc', signedIn: true);
      expect(find.text('Sahifa topilmadi'), findsOneWidget);
    });

    testWidgets('/review/new without ids shows Sahifa topilmadi', (t) async {
      await pumpBizcat(t, location: '/review/new', signedIn: true);
      expect(find.text('Sahifa topilmadi'), findsOneWidget);
    });

    testWidgets('/review/new with both ids shows Sahifa topilmadi', (t) async {
      await pumpBizcat(t, location: '/review/new?appointment=1&order=2', signedIn: true);
      expect(find.text('Sahifa topilmadi'), findsOneWidget);
    });

    testWidgets('an unknown path shows Sahifa topilmadi', (t) async {
      await pumpBizcat(t, location: '/no/such/page');
      expect(find.text('Sahifa topilmadi'), findsOneWidget);
    });

    testWidgets('/ -> /home', (t) async {
      final h = await pumpBizcat(t, location: '/');
      expect(h.location, '/home');
    });
  });

  group('shell', () {
    testWidgets('5 tabs; tapping switches branches', (t) async {
      final h = await pumpBizcat(t, signedIn: true);
      for (final label in ['Asosiy', 'Katalog', 'Bronlarim', 'Sevimlilar', 'Profil']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
      }
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Katalog')));
      await settle(t);
      expect(h.location, '/explore');
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')));
      await settle(t);
      expect(h.location, '/profile');
    });

    testWidgets('tapping the active tab pops to its root', (t) async {
      final h = await pumpBizcat(t, signedIn: true, location: '/profile/wallet');
      expect(find.byType(NavigationBar), findsOneWidget);
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profil')));
      await settle(t);
      expect(h.location, '/profile');
    });

    testWidgets('top-level routes have no bottom bar', (t) async {
      await pumpBizcat(t, location: '/b/shox-barber');
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}

/// Unmounts the app and lets in-flight fake requests (chained loads on unstubbed
/// endpoints) finish, so no Dio timer is pending at teardown.
Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}
