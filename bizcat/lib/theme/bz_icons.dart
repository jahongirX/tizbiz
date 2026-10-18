import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';
import 'package:material_ui/material_ui.dart';

/// The app's icon set: Lucide (outlined, rounded). Light weight (300) for regular icons, heavy
/// weight (600) for selected states. Widgets use these names, never `Icons.*` directly, so the
/// set can change in one place. Filled glyphs Lucide lacks (filled heart, stars, radio) stay
/// Material.
abstract final class BzIcons {
  // navigation
  static const home = LucideIcons300.house;
  static const homeBold = LucideIcons600.house;
  static const catalog = LucideIcons300.layoutGrid;
  static const catalogBold = LucideIcons600.layoutGrid;
  static const bookings = LucideIcons300.calendarDays;
  static const bookingsBold = LucideIcons600.calendarDays;
  static const profile = LucideIcons300.circleUserRound;
  static const profileBold = LucideIcons600.circleUserRound;
  static const map = LucideIcons300.mapPinned;
  static const mapBold = LucideIcons600.mapPinned;

  // actions / chrome
  static const search = LucideIcons300.search;
  static const chevronRight = LucideIcons300.chevronRight;
  static const chevronLeft = LucideIcons300.chevronLeft;
  static const back = LucideIcons300.arrowLeft;
  static const forward = LucideIcons300.arrowRight;
  static const expandMore = LucideIcons300.chevronDown;
  static const expandLess = LucideIcons300.chevronUp;
  static const close = LucideIcons300.x;
  static const check = LucideIcons300.check;
  static const add = LucideIcons300.plus;
  static const remove = LucideIcons300.minus;
  static const edit = LucideIcons300.pencil;
  static const delete = LucideIcons300.trash2;
  static const refresh = LucideIcons300.refreshCw;
  static const retry = LucideIcons300.rotateCcw;
  static const send = LucideIcons300.send;
  static const openExternal = LucideIcons300.externalLink;
  static const filter = LucideIcons300.slidersHorizontal;
  static const sort = LucideIcons300.arrowUpDown;
  static const more = LucideIcons300.ellipsisVertical;
  static const logout = LucideIcons300.logOut;
  static const lock = LucideIcons300.lock;
  static const share = LucideIcons300.share2;

  // places / contact
  static const location = LucideIcons300.mapPin;
  static const locationBold = LucideIcons600.mapPin;
  static const myLocation = LucideIcons300.locateFixed;
  static const route = LucideIcons300.route;
  static const fitAll = LucideIcons300.maximize;
  static const call = LucideIcons300.phone;
  static const callOff = LucideIcons300.phoneOff;
  static const globe = LucideIcons300.globe;
  static const language = LucideIcons300.languages;

  // domain
  static const shop = LucideIcons300.store;
  static const heart = LucideIcons300.heart;
  static const heartBold = Icons.favorite_rounded;
  static const star = Icons.star_rounded;
  static const starOutline = LucideIcons300.star;
  static const review = LucideIcons300.messageSquareText;
  static const clock = LucideIcons300.clock;
  static const history = LucideIcons300.history;
  static const calendar = LucideIcons300.calendar;
  static const calendarTick = LucideIcons300.calendarCheck;
  static const calendarRemove = LucideIcons300.calendarX;
  static const wallet = LucideIcons300.wallet;
  static const gift = LucideIcons300.gift;
  static const receipt = LucideIcons300.receipt;
  static const bag = LucideIcons300.shoppingBag;
  static const card = LucideIcons300.creditCard;
  static const menuBoard = LucideIcons300.bookOpen;
  static const category = LucideIcons300.layoutGrid;
  static const verify = LucideIcons300.badgeCheck;
  static const security = LucideIcons300.shieldCheck;
  static const user = LucideIcons300.user;
  static const userOff = LucideIcons300.userX;
  static const info = LucideIcons300.info;
  static const danger = LucideIcons300.circleAlert;
  static const tick = LucideIcons300.circleCheck;
  static const image = LucideIcons300.image;
  static const offline = LucideIcons300.wifiOff;
  static const searchEmpty = LucideIcons300.searchX;
  static const sun = LucideIcons300.sun;
  static const moon = LucideIcons300.moon;
  static const block = LucideIcons300.ban;

  // categories
  static const scissor = LucideIcons300.scissors;
  static const cake = LucideIcons300.cakeSlice;
  static const restaurant = LucideIcons300.utensils;
  static const hospital = LucideIcons300.stethoscope;
  static const wedding = LucideIcons300.partyPopper;
}
