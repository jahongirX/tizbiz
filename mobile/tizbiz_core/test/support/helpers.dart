import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Decodes a fixture and returns its envelope `data` as a map.
Map<String, dynamic> dataMap(String raw) => JsonRead.object((jsonDecode(raw) as Map<String, dynamic>)['data']);

/// Decodes a fixture and returns its envelope `data` list items.
List<Map<String, dynamic>> dataList(String raw) {
  final data = (jsonDecode(raw) as Map<String, dynamic>)['data'];
  return [for (final e in data as List<dynamic>) JsonRead.object(e)];
}

/// Decodes a fixture and returns its envelope `meta`.
Map<String, dynamic> metaMap(String raw) => JsonRead.object((jsonDecode(raw) as Map<String, dynamic>)['meta']);

/// The fixed-point property: `X.fromJson(x.toJson()).toJson()` deep-equals `x.toJson()`,
/// also after a real JSON encode/decode round trip.
void expectFixedPoint<T>(T value, Map<String, dynamic> Function(T) toJson, T Function(Map<String, dynamic>) fromJson) {
  const eq = DeepCollectionEquality();
  final once = toJson(value);
  final twice = toJson(fromJson(once));
  expect(eq.equals(twice, once), isTrue, reason: 'not a fixed point:\n$once\n$twice');
  final viaWire = toJson(fromJson(jsonDecode(jsonEncode(once)) as Map<String, dynamic>));
  expect(eq.equals(viaWire, once), isTrue, reason: 'not a fixed point through JSON:\n$once\n$viaWire');
}
