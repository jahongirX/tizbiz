/// Every path the apps call. Paths start with '/v1/'.
///
/// Which RequestAuth to use: `none` for [login], [consumerOtp], [consumerVerify], `site*`,
/// [availability], [paymentsDeposit]; `auto` for everything else (directory endpoints accept an
/// optional consumer token for `is_favorite`). The business app must never call public
/// `POST /v1/appointments` with a staff token (403) and only uses it as owner/admin (admin mode).
abstract final class Endpoints {
  // business auth & team (TizBiz Biznes)
  static const login = '/v1/auth/login';
  static const authMe = '/v1/auth/me';
  static String switchBusiness(int businessId) => '/v1/auth/switch/$businessId';
  static const team = '/v1/team';
  static String teamMember(int userId) => '/v1/team/$userId';

  // staff self-service
  static const meStaff = '/v1/me/staff';
  static const meStats = '/v1/me/stats';
  static const meSchedule = '/v1/me/schedule';
  static const meAppointments = '/v1/me/appointments';
  static String meAppointment(int id) => '/v1/me/appointments/$id';

  // tenant data (business token)
  static const staff = '/v1/staff';
  static String staffById(int id) => '/v1/staff/$id';
  static String workingHours(int staffId) => '/v1/staff/$staffId/working-hours';
  static String timeOff(int staffId) => '/v1/staff/$staffId/time-off';
  static String timeOffItem(int staffId, int id) => '/v1/staff/$staffId/time-off/$id';
  static const services = '/v1/services';
  static String service(int id) => '/v1/services/$id';
  static const serviceCategories = '/v1/service-categories';
  static String serviceCategory(int id) => '/v1/service-categories/$id';
  static const bookingSettings = '/v1/settings/booking';

  /// Owner/admin only (BP §2b).
  static const uploads = '/v1/uploads';
  static const appointments = '/v1/appointments';
  static String appointment(int id) => '/v1/appointments/$id';
  static const orders = '/v1/orders';
  static String order(int id) => '/v1/orders/$id';
  static const clients = '/v1/clients';
  static String client(int id) => '/v1/clients/$id';
  static String clientCategoriesOf(int clientId) => '/v1/clients/$clientId/categories';
  static const clientCategories = '/v1/client-categories';
  static const analyticsOverview = '/v1/analytics/overview';
  static const financeSummary = '/v1/finance/summary';
  static const financeTransactions = '/v1/finance/transactions';
  static const payroll = '/v1/payroll';
  static const reviews = '/v1/reviews';
  static String reviewReply(int id) => '/v1/reviews/$id/reply';

  // public (no token)
  static String availability(int staffId) => '/v1/staff/$staffId/availability';
  static String site(String slug) => '/v1/site/${Uri.encodeComponent(slug)}';
  static String siteBookedDays(String slug) => '/v1/site/${Uri.encodeComponent(slug)}/booked-days';
  static const paymentsDeposit = '/v1/payments/deposit';

  // directory (optional consumer token)
  static const directoryCategories = '/v1/directory/categories';
  static const directoryBusinesses = '/v1/directory/businesses';
  static const directoryMap = '/v1/directory/map';
  static String directoryBusiness(String slug) => '/v1/directory/businesses/${Uri.encodeComponent(slug)}';
  static String directoryReviews(String slug) =>
      '/v1/directory/businesses/${Uri.encodeComponent(slug)}/reviews';

  // consumer (Bizcat)
  static const consumerOtp = '/v1/consumer/auth/otp';
  static const consumerVerify = '/v1/consumer/auth/verify';
  static const consumerMe = '/v1/consumer/me';
  static const consumerFavorites = '/v1/consumer/favorites';
  static String consumerFavorite(int businessId) => '/v1/consumer/favorites/$businessId';
  static const consumerAppointments = '/v1/consumer/appointments';
  static String consumerAppointment(int id) => '/v1/consumer/appointments/$id';
  static String consumerAppointmentCancel(int id) => '/v1/consumer/appointments/$id/cancel';
  static const consumerOrders = '/v1/consumer/orders';
  static String consumerOrder(int id) => '/v1/consumer/orders/$id';
  static String consumerOrderCancel(int id) => '/v1/consumer/orders/$id/cancel';
  static const consumerLoyalty = '/v1/consumer/loyalty';
  static const consumerReviews = '/v1/consumer/reviews';
  static String consumerReview(int id) => '/v1/consumer/reviews/$id';
}
