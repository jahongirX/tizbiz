import 'dart:math';

import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('newKey is a v4 UUID', () {
    for (var i = 0; i < 50; i++) {
      final k = Idempotency.newKey();
      expect(k, matches(uuid));
      expect(k.length, 36);
    }
  });

  test('1000 keys are unique', () {
    final keys = {for (var i = 0; i < 1000; i++) Idempotency.newKey()};
    expect(keys.length, 1000);
  });

  test('seeded random is deterministic', () {
    expect(Idempotency.newKey(Random(1)), Idempotency.newKey(Random(1)));
    expect(Idempotency.newKey(Random(1)), matches(uuid));
  });

  test('deposit key', () {
    expect(Idempotency.deposit(5012), 'dep-5012-payme');
    expect(Idempotency.header, 'Idempotency-Key');
  });
}
