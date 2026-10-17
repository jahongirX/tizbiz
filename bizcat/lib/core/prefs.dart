import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// The app's [SharedPreferences]. Overridden in `main()` (and by `pumpBizcat` in tests).
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main'));

/// Typed access to the persisted per-device preferences.
final appPrefsProvider = Provider<AppPrefs>((ref) => AppPrefs(ref.watch(prefsProvider)));

/// Typed wrapper over [SharedPreferences]. Every read falls back to its default on any error.
final class AppPrefs {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const kOnboarded = 'bizcat.onboarded';
  static const kCity = 'bizcat.city';
  static const kProfile = 'bizcat.profile';
  static const kRecentSearches = 'bizcat.recent_searches';
  static const int maxRecentSearches = 8;

  /// Whether the first-run onboarding was finished.
  bool get onboarded {
    try {
      return _prefs.getBool(kOnboarded) ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> setOnboarded(bool v) async {
    try {
      await _prefs.setBool(kOnboarded, v);
    } on Object catch (e) {
      debugPrint('prefs: setOnboarded failed: $e');
    }
  }

  /// null/'' = all cities.
  String? get city {
    try {
      final v = _prefs.getString(kCity)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    } on Object {
      return null;
    }
  }

  Future<void> setCity(String? v) async {
    try {
      final c = v?.trim();
      if (c == null || c.isEmpty) {
        await _prefs.remove(kCity);
      } else {
        await _prefs.setString(kCity, c);
      }
    } on Object catch (e) {
      debugPrint('prefs: setCity failed: $e');
    }
  }

  /// The last known profile (ConsumerUser.toJson string), for offline restore.
  ConsumerUser? get cachedProfile {
    try {
      final raw = _prefs.getString(kProfile);
      if (raw == null || raw.isEmpty) return null;
      final json = JsonRead.objectOrNull(jsonDecode(raw));
      if (json == null) return null;
      return ConsumerUser.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> setCachedProfile(ConsumerUser? u) async {
    try {
      if (u == null) {
        await _prefs.remove(kProfile);
      } else {
        await _prefs.setString(kProfile, jsonEncode(u.toJson()));
      }
    } on Object catch (e) {
      debugPrint('prefs: setCachedProfile failed: $e');
    }
  }

  /// Most recent first, max [maxRecentSearches].
  List<String> get recentSearches {
    try {
      return List.unmodifiable(_prefs.getStringList(kRecentSearches) ?? const <String>[]);
    } on Object {
      return const [];
    }
  }

  /// Trims, de-duplicates (case-insensitive, the newest spelling wins) and ignores < 2 chars.
  Future<void> addRecentSearch(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final next = <String>[
      t,
      for (final s in recentSearches)
        if (s.toLowerCase() != t.toLowerCase()) s,
    ];
    try {
      await _prefs.setStringList(kRecentSearches, next.take(maxRecentSearches).toList());
    } on Object catch (e) {
      debugPrint('prefs: addRecentSearch failed: $e');
    }
  }

  Future<void> clearRecentSearches() async {
    try {
      await _prefs.remove(kRecentSearches);
    } on Object catch (e) {
      debugPrint('prefs: clearRecentSearches failed: $e');
    }
  }
}
