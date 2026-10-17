import 'package:flutter/foundation.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Engine-dependent texts of the catalog flow (BIZCAT-SPEC §9.8): a cafe or bakery sells
/// products, a clinic (medical engine without staff) takes service requests.
@immutable
final class CatalogCopy {
  const CatalogCopy._({
    required this.menuTitle,
    required this.cartTitle,
    required this.submit,
    required this.emptyCart,
    required this.pickupNote,
    required this.emptyMenu,
    required this.placed,
  });

  /// Picks the copy for [engine]; everything except medical uses the catalog texts.
  factory CatalogCopy.forEngine(Engine? engine) => engine == Engine.medical ? medical : catalog;

  static const CatalogCopy catalog = CatalogCopy._(
    menuTitle: 'Menyu',
    cartTitle: 'Savat',
    submit: 'Buyurtma berish',
    emptyCart: "Savat bo'sh",
    pickupNote: "Yetkazib berish yo'q: buyurtmani joyida olasiz.",
    emptyMenu: "Menyu hali bo'sh",
    placed: 'Buyurtma qabul qilindi.',
  );

  static const CatalogCopy medical = CatalogCopy._(
    menuTitle: 'Xizmatlar',
    cartTitle: 'Tanlangan xizmatlar',
    submit: "So'rov yuborish",
    emptyCart: 'Hech narsa tanlanmagan',
    pickupNote: "Klinika siz bilan bog'lanib, vaqtni kelishadi.",
    emptyMenu: "Xizmatlar ro'yxati hali bo'sh",
    placed: "So'rovingiz yuborildi.",
  );

  final String menuTitle;
  final String cartTitle;
  final String submit;
  final String emptyCart;
  final String pickupNote;

  /// The empty-menu state title.
  final String emptyMenu;

  /// Snackbar after a successful POST.
  final String placed;
}

/// Shared phrases of the catalog screens.
abstract final class CatalogText {
  static const add = "Qo'shish";
  static const addToCart = "Savatga qo'shish";
  static const updateCart = 'Savatni yangilash';
  static const viewCart = "Savatni ko'rish";
  static const checkout = 'Rasmiylashtirish';
  static const total = 'Jami';
  static const backToMenu = 'Menyuga qaytish';
  static const increase = "Ko'paytirish";
  static const decrease = 'Kamaytirish';
  static const remove = 'Olib tashlash';
  static const clearCart = 'Savatni tozalash';
  static const itemsGone = "Ba'zi mahsulotlar endi mavjud emas.";
  static const reorderApplied = "Oldingi buyurtma savatga qo'shildi.";
  static const reorderFailed = "Oldingi buyurtmani yuklab bo'lmadi.";
  static const ordersClosed = 'Bu biznes hozir onlayn buyurtma qabul qilmaydi.';
  static const call = "Qo'ng'iroq qilish";
  static const close = 'Yopish';
  static const nameLabel = 'Ismingiz';
  static const nameError = "Ism 2 dan 64 belgigacha bo'lishi kerak.";
  static const noteLabel = 'Izoh (ixtiyoriy)';
  static const noteHint = 'Masalan: soat 17:00 da olib ketaman';
  static const noteError = 'Izoh 500 belgidan oshmasligi kerak.';
  static const phoneNote = "Biznes siz bilan shu raqam orqali bog'lanadi.";
  static const other = 'Boshqa';

  /// 'Savat · 2 ta'.
  static String cartCount(int n) => 'Savat · $n ta';
}
