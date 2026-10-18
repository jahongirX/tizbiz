import 'package:tizbiz_core/tizbiz_core.dart';

import '../app/routes.dart';

/// Which booking screen a business uses.
enum BookingFlow { slot, rental, catalog }

/// From the storefront payload (authoritative): rental -> rental; catalog -> catalog;
/// slot -> slot; medical -> slot when it has both services and staff, else catalog.
BookingFlow bookingFlowFor(StorefrontData s) => switch (s.engine) {
  Engine.rental => BookingFlow.rental,
  Engine.catalog => BookingFlow.catalog,
  Engine.slot => BookingFlow.slot,
  Engine.medical => s.services.isNotEmpty && s.staff.isNotEmpty ? BookingFlow.slot : BookingFlow.catalog,
};

/// When only the engine is known (cards, revisit items). Screens re-check with
/// [bookingFlowFor] after loading the storefront.
BookingFlow bookingFlowForEngine(Engine e) => switch (e) {
  Engine.rental => BookingFlow.rental,
  Engine.catalog => BookingFlow.catalog,
  Engine.medical => BookingFlow.catalog,
  Engine.slot => BookingFlow.slot,
};

/// AppRoutes.bookSlot / bookRental / menu.
String bookingEntryPath(String slug, BookingFlow f, {int? serviceId, int? staffId}) => switch (f) {
  BookingFlow.slot => AppRoutes.bookSlot(slug, serviceId: serviceId, staffId: staffId),
  BookingFlow.rental => AppRoutes.bookRental(slug),
  BookingFlow.catalog => AppRoutes.menu(slug),
};

/// Primary CTA text on the business page.
String ctaLabelFor(BookingFlow f, Engine e) => switch (f) {
  BookingFlow.slot => 'Navbatga yozilish',
  BookingFlow.rental => 'Sanani band qilish',
  BookingFlow.catalog => e == Engine.medical ? 'Xizmatni tanlash' : 'Buyurtma berish',
};
