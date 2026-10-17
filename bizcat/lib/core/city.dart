import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// Demo data is in Toshkent; Termiz is the target market.
const List<String> kCities = ['Toshkent', 'Termiz'];

/// The selected city (null = all cities), persisted in prefs.
final cityProvider = NotifierProvider<CityController, String?>(CityController.new);

class CityController extends Notifier<String?> {
  @override
  String? build() => ref.read(appPrefsProvider).city;

  /// null = all cities. Persisted.
  Future<void> set(String? city) async {
    final c = city?.trim();
    final v = (c == null || c.isEmpty) ? null : c;
    state = v;
    await ref.read(appPrefsProvider).setCity(v);
  }
}

/// 'Barcha shaharlar' for null.
String cityLabel(String? city) => city ?? 'Barcha shaharlar';
