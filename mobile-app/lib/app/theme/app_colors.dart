import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Badge colours: background + foreground.
typedef StatusColors = ({Color bg, Color fg});

/// Design tokens of the web cabinet (apps/admin/src/style.css) as a theme extension.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.warning,
    required this.pending,
    required this.confirmed,
    required this.arrived,
    required this.completed,
    required this.noShow,
    required this.canceled,
  });

  static const Color defaultPrimaryLight = Color(0xFF2563EB);
  static const Color defaultPrimaryDark = Color(0xFF3B82F6);

  /// Amber of [StarRating].
  static const Color star = Color(0xFFF59E0B);

  static const AppColors light = AppColors(
    bg: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F2F5),
    border: Color(0xFFE2E5EA),
    text: Color(0xFF1A1D23),
    textMuted: Color(0xFF6B7280),
    primary: defaultPrimaryLight,
    primarySoft: Color(0xFFE0E9FC), // #2563EB 14% over #FFFFFF
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFDECEC),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    pending: (bg: Color(0xFFFEF3C7), fg: Color(0xFF92400E)),
    confirmed: (bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF)),
    arrived: (bg: Color(0xFFE0E7FF), fg: Color(0xFF3730A3)),
    completed: (bg: Color(0xFFDCFCE7), fg: Color(0xFF166534)),
    noShow: (bg: Color(0xFFFEE2E2), fg: Color(0xFF991B1B)),
    canceled: (bg: Color(0xFFF3F4F6), fg: Color(0xFF6B7280)),
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surface2: Color(0xFF21252D),
    border: Color(0xFF2B303A),
    text: Color(0xFFE8EAED),
    textMuted: Color(0xFF9AA1AC),
    primary: defaultPrimaryDark,
    primarySoft: Color(0xFF1D293F), // #3B82F6 14% over #181B21
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0xFF2A1618),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    pending: (bg: Color(0xFF3A2E12), fg: Color(0xFFFBBF24)),
    confirmed: (bg: Color(0xFF14284A), fg: Color(0xFF93C5FD)),
    arrived: (bg: Color(0xFF1E1B4B), fg: Color(0xFFA5B4FC)),
    completed: (bg: Color(0xFF14331F), fg: Color(0xFF86EFAC)),
    noShow: (bg: Color(0xFF3A1616), fg: Color(0xFFFCA5A5)),
    canceled: (bg: Color(0xFF262A31), fg: Color(0xFF9AA1AC)),
  );

  /// Order board colours (Orders.vue columns); badge bg = colour 15%.
  static const Map<OrderStatus, Color> orderStatus = {
    OrderStatus.newOrder: Color(0xFF3B82F6),
    OrderStatus.confirmed: Color(0xFF8B5CF6),
    OrderStatus.preparing: Color(0xFFF59E0B),
    OrderStatus.ready: Color(0xFF10B981),
    OrderStatus.delivered: Color(0xFF6B7280),
    OrderStatus.cancelled: Color(0xFFEF4444),
    OrderStatus.unknown: Color(0xFF6B7280),
  };

  /// Light tokens when the theme has no extension (should not happen inside the app).
  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? light;

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color warning;
  final StatusColors pending;
  final StatusColors confirmed;
  final StatusColors arrived;
  final StatusColors completed;
  final StatusColors noShow;
  final StatusColors canceled;

  /// The tokens with [accent] as primary (primarySoft = accent 14% over surface).
  AppColors withPrimary(Color? accent) {
    if (accent == null) return this;
    return copyWith(primary: accent, primarySoft: Color.alphaBlend(accent.withValues(alpha: 0.14), surface));
  }

  StatusColors appointmentStatus(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => pending,
        AppointmentStatus.confirmed => confirmed,
        AppointmentStatus.arrived => arrived,
        AppointmentStatus.completed => completed,
        AppointmentStatus.noShow => noShow,
        AppointmentStatus.canceled || AppointmentStatus.unknown => canceled,
      };

  /// Dot / left-border colour of an order status.
  Color orderStatusColor(OrderStatus s) => orderStatus[s] ?? textMuted;

  /// Badge colours of an order status: colour 15% over surface + the colour.
  StatusColors orderStatusBadge(OrderStatus s) {
    final c = orderStatusColor(s);
    return (bg: Color.alphaBlend(c.withValues(alpha: 0.15), surface), fg: c);
  }

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? primary,
    Color? primarySoft,
    Color? danger,
    Color? dangerSoft,
    Color? success,
    Color? warning,
    StatusColors? pending,
    StatusColors? confirmed,
    StatusColors? arrived,
    StatusColors? completed,
    StatusColors? noShow,
    StatusColors? canceled,
  }) =>
      AppColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surface2: surface2 ?? this.surface2,
        border: border ?? this.border,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        primary: primary ?? this.primary,
        primarySoft: primarySoft ?? this.primarySoft,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        pending: pending ?? this.pending,
        confirmed: confirmed ?? this.confirmed,
        arrived: arrived ?? this.arrived,
        completed: completed ?? this.completed,
        noShow: noShow ?? this.noShow,
        canceled: canceled ?? this.canceled,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    StatusColors s(StatusColors a, StatusColors b) => (bg: c(a.bg, b.bg), fg: c(a.fg, b.fg));
    return AppColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      border: c(border, other.border),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      primary: c(primary, other.primary),
      primarySoft: c(primarySoft, other.primarySoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      pending: s(pending, other.pending),
      confirmed: s(confirmed, other.confirmed),
      arrived: s(arrived, other.arrived),
      completed: s(completed, other.completed),
      noShow: s(noShow, other.noShow),
      canceled: s(canceled, other.canceled),
    );
  }
}
