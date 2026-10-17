import 'package:bizcat/app/routes.dart';
import 'package:bizcat/app/shell.dart';
import 'package:bizcat/core/prefs.dart';
import 'package:bizcat/core/session.dart';
import 'package:bizcat/features/auth/login_name_screen.dart';
import 'package:bizcat/features/auth/login_phone_screen.dart';
import 'package:bizcat/features/auth/otp_code_screen.dart';
import 'package:bizcat/features/booking_catalog/cart_screen.dart';
import 'package:bizcat/features/booking_catalog/checkout_screen.dart';
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
import 'package:bizcat/shared/screens/not_found_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Where the router starts (a cold start always goes through the splash). Tests may override it
/// to simulate a deep link.
final initialLocationProvider = Provider<String>((_) => AppRoutes.splash);

/// Root navigator (top-level routes: no bottom bar).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Bumped on every session change so the router re-runs its redirect.
final class RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// The app router: every route of BIZCAT-SPEC §5.1, the redirects of §5.3 and the 5-tab shell.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  ref
    ..listen<SessionState>(sessionProvider, (_, _) => refresh.bump())
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      state.uri,
      session: ref.read(sessionProvider),
      onboarded: ref.read(appPrefsProvider).onboarded,
    ),
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: buildAppRoutes(),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// The redirect rules of BIZCAT-SPEC §5.3 (pure, unit-testable).
String? appRedirect(Uri loc, {required SessionState session, required bool onboarded}) {
  final path = loc.path;
  final from = loc.queryParameters['from'];

  // 1. '/' -> home.
  if (path == '/' || path.isEmpty) return AppRoutes.home;

  // 2. Restore still running: hold on the splash, remembering where we were going.
  if (session is SessionUnknown) {
    if (path == AppRoutes.splash) return null;
    return Uri(path: AppRoutes.splash, queryParameters: {'from': loc.toString()}).toString();
  }

  // 3. Leave the splash once the session is known.
  if (path == AppRoutes.splash) {
    final target = safeFrom(from);
    if (!onboarded) return AppRoutes.onboardingWith(from: target);
    return target ?? AppRoutes.home;
  }

  final signedIn = session is SessionSignedIn;

  // 4. Auth-required routes.
  if (!signedIn && routeRequiresAuth(loc)) {
    final expired = session is SessionSignedOut && session.reason == SignOutReason.expired;
    return AppRoutes.loginWith(from: loc.toString(), expired: expired);
  }

  // 5. Already signed in: skip the phone/code steps.
  if (signedIn && (path == AppRoutes.login || path == AppRoutes.loginCode)) {
    return safeFrom(from) ?? AppRoutes.home;
  }

  // /login/code needs the phone.
  if (path == AppRoutes.loginCode && (loc.queryParameters['phone'] ?? '').trim().isEmpty) {
    return AppRoutes.loginWith(from: from);
  }

  return null;
}

int? _int(String? s) => s == null ? null : int.tryParse(s);
String? _str(String? s) => (s == null || s.trim().isEmpty) ? null : s;

/// The route tree (top-level routes on the root navigator plus the shell branches).
List<RouteBase> buildAppRoutes() => [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: AppRoutes.splash, name: 'splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (_, s) => OnboardingScreen(from: _str(s.uri.queryParameters['from'])),
      ),
      GoRoute(path: AppRoutes.city, name: 'city', builder: (_, _) => const CityPickerScreen()),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, s) => LoginPhoneScreen(
          from: _str(s.uri.queryParameters['from']),
          expired: s.uri.queryParameters['expired'] == '1',
        ),
        routes: [
          GoRoute(
            path: 'code',
            name: 'loginCode',
            builder: (_, s) => OtpCodeScreen(
              phone: s.uri.queryParameters['phone'] ?? '',
              from: _str(s.uri.queryParameters['from']),
            ),
          ),
          GoRoute(
            path: 'name',
            name: 'loginName',
            builder: (_, s) => LoginNameScreen(from: _str(s.uri.queryParameters['from'])),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, name: 'home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.explore,
              name: 'explore',
              builder: (_, s) {
                final q = s.uri.queryParameters;
                return DirectoryScreen(
                  q: _str(q['q']),
                  category: _str(q['category']),
                  sort: _str(q['sort']),
                  focus: q['focus'] == '1',
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.bookings,
              name: 'bookings',
              builder: (_, s) => MyBookingsScreen(tab: _str(s.uri.queryParameters['tab'])),
              routes: [
                GoRoute(
                  path: 'a/:id',
                  name: 'appointment',
                  builder: (_, s) {
                    final id = _int(s.pathParameters['id']);
                    if (id == null) return const NotFoundScreen();
                    return AppointmentDetailScreen(id: id, justCreated: s.uri.queryParameters['new'] == '1');
                  },
                ),
                GoRoute(
                  path: 'o/:id',
                  name: 'order',
                  builder: (_, s) {
                    final id = _int(s.pathParameters['id']);
                    if (id == null) return const NotFoundScreen();
                    return OrderDetailScreen(id: id, justCreated: s.uri.queryParameters['new'] == '1');
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.favorites, name: 'favorites', builder: (_, _) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'edit', name: 'profileEdit', builder: (_, _) => const ProfileEditScreen()),
                GoRoute(path: 'wallet', name: 'wallet', builder: (_, _) => const LoyaltyWalletScreen()),
                GoRoute(path: 'reviews', name: 'myReviews', builder: (_, _) => const MyReviewsScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/b/:slug',
        name: 'business',
        builder: (_, s) => BusinessScreen(
          slug: s.pathParameters['slug']!,
          tab: _str(s.uri.queryParameters['tab']),
        ),
        routes: [
          GoRoute(
            path: 'reviews',
            name: 'businessReviews',
            builder: (_, s) => BusinessReviewsScreen(slug: s.pathParameters['slug']!),
          ),
          GoRoute(
            path: 'book',
            name: 'bookSlot',
            builder: (_, s) => SlotBookingScreen(
              slug: s.pathParameters['slug']!,
              serviceId: _int(s.uri.queryParameters['service']),
              staffId: _int(s.uri.queryParameters['staff']),
            ),
          ),
          GoRoute(
            path: 'rent',
            name: 'bookRental',
            builder: (_, s) => RentalBookingScreen(slug: s.pathParameters['slug']!),
          ),
          GoRoute(
            path: 'menu',
            name: 'menu',
            builder: (_, s) => MenuScreen(
              slug: s.pathParameters['slug']!,
              reorderOrderId: _int(s.uri.queryParameters['reorder']),
            ),
          ),
          GoRoute(path: 'cart', name: 'cart', builder: (_, s) => CartScreen(slug: s.pathParameters['slug']!)),
          GoRoute(
            path: 'checkout',
            name: 'checkout',
            builder: (_, s) => CheckoutScreen(slug: s.pathParameters['slug']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.reviewNewPath,
        name: 'reviewNew',
        builder: (_, s) {
          final q = s.uri.queryParameters;
          final appointmentId = _int(q['appointment']);
          final orderId = _int(q['order']);
          if ((appointmentId == null) == (orderId == null)) return const NotFoundScreen();
          return ReviewComposeScreen(
            appointmentId: appointmentId,
            orderId: orderId,
            businessName: _str(q['bname']),
          );
        },
      ),
      GoRoute(
        path: '/review/:id/edit',
        name: 'reviewEdit',
        builder: (_, s) {
          final id = _int(s.pathParameters['id']);
          if (id == null) return const NotFoundScreen();
          return ReviewComposeScreen(reviewId: id);
        },
      ),
    ];
