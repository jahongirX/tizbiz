import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tizbiz_core/tizbiz_core.dart';
import 'package:url_launcher/url_launcher.dart';

import 'messenger.dart';

/// Opens URLs in an external application. Tests override [urlOpenerProvider] with a fake.
abstract interface class UrlOpener {
  Future<bool> open(Uri uri);
}

/// url_launcher, external application.
final class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('launcher: $uri failed: $e');
      return false;
    }
  }
}

final urlOpenerProvider = Provider<UrlOpener>((_) => const UrlLauncherOpener());

/// The URL [openMap] would open, or null when nothing is known.
/// Precedence: mapUrl -> lat/lng (Yandex) -> `https://maps.google.com/?q=<name, address>`.
Uri? mapTarget({String? mapUrl, double? lat, double? lng, String? name, String? address}) {
  final m = mapUrl?.trim();
  if (m != null && m.isNotEmpty) {
    final u = Uri.tryParse(m);
    if (u != null && u.hasScheme) return u;
  }
  if (lat != null && lng != null) {
    return Uri.parse('https://yandex.uz/maps/?pt=$lng,$lat&z=17&l=map');
  }
  final a = address?.trim() ?? '';
  if (a.isEmpty) return null;
  final n = name?.trim() ?? '';
  final q = n.isEmpty ? a : '$n, $a';
  return Uri.https('maps.google.com', '/', {'q': q});
}

/// Whether [openMap] has anything to open (hide the button otherwise).
bool hasMapTarget({String? mapUrl, double? lat, double? lng, String? name, String? address}) =>
    mapTarget(mapUrl: mapUrl, lat: lat, lng: lng, name: name, address: address) != null;

Future<bool> _open(WidgetRef ref, Uri? uri) async {
  if (uri == null) {
    showSnack("Ochib bo'lmadi.");
    return false;
  }
  final ok = await ref.read(urlOpenerProvider).open(uri);
  if (!ok) showSnack("Ochib bo'lmadi.");
  return ok;
}

/// Opens the business location (see [mapTarget]). false + snackbar `Ochib bo'lmadi.` on failure.
Future<bool> openMap(WidgetRef ref, {String? mapUrl, double? lat, double? lng, String? name, String? address}) =>
    _open(ref, mapTarget(mapUrl: mapUrl, lat: lat, lng: lng, name: name, address: address));

/// `tel:+998...` via [Phone.telUri].
Future<bool> callPhone(WidgetRef ref, String? phone) => _open(ref, Phone.telUri(phone));

/// `https://t.me/<username without @>`.
Future<bool> openTelegram(WidgetRef ref, String username) {
  var u = username.trim();
  while (u.startsWith('@')) {
    u = u.substring(1);
  }
  return _open(ref, u.isEmpty ? null : Uri.parse('https://t.me/${Uri.encodeComponent(u)}'));
}
