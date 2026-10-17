import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('integer', () {
    expect(JsonRead.integer(1), 1);
    expect(JsonRead.integer('12'), 12);
    expect(JsonRead.integer('12.0'), 12);
    expect(JsonRead.integer(12.9), 12);
    expect(JsonRead.integer(true), 1);
    expect(JsonRead.integer(null), 0);
    expect(JsonRead.integer('x', 7), 7);
    expect(JsonRead.integerOrNull(''), isNull);
    expect(JsonRead.integerOrNull(null), isNull);
    expect(JsonRead.integerOrNull('abc'), isNull);
  });

  test('number', () {
    expect(JsonRead.numberOrNull('41.2756000'), 41.2756);
    expect(JsonRead.numberOrNull(69), 69.0);
    expect(JsonRead.numberOrNull(69), isA<double>());
    expect(JsonRead.numberOrNull(null), isNull);
    expect(JsonRead.number('x', 2.5), 2.5);
  });

  test('boolean', () {
    for (final v in [1, '1', true, 'TRUE', 'true']) {
      expect(JsonRead.boolean(v), isTrue, reason: '$v');
    }
    for (final v in [0, '0', false, 'false', null]) {
      expect(JsonRead.boolean(v), isFalse, reason: '$v');
    }
    expect(JsonRead.boolean(null, true), isTrue);
    expect(JsonRead.booleanOrNull(null), isNull);
    expect(JsonRead.booleanOrNull('maybe'), isNull);
  });

  test('object / objectOrNull', () {
    expect(JsonRead.object(<dynamic>[]), <String, dynamic>{});
    expect(JsonRead.object({'a': 1}), {'a': 1});
    expect(() => JsonRead.object('x'), throwsFormatException);
    expect(() => JsonRead.object(null), throwsFormatException);
    expect(() => JsonRead.object([1]), throwsFormatException);
    expect(JsonRead.objectOrNull(<dynamic>[]), isNull);
    expect(JsonRead.objectOrNull({1: 'a'}), {'1': 'a'});
  });

  test('strings', () {
    expect(JsonRead.string(12), '12');
    expect(JsonRead.string(null, 'x'), 'x');
    expect(JsonRead.stringOrNull(''), '');
    expect(JsonRead.nonEmptyOrNull('  '), isNull);
    expect(JsonRead.nonEmptyOrNull(''), isNull);
    expect(JsonRead.nonEmptyOrNull('a'), 'a');
  });

  test('stringList', () {
    expect(JsonRead.stringList(['a', 'b']), ['a', 'b']);
    expect(JsonRead.stringList('["a","b"]'), ['a', 'b']);
    expect(JsonRead.stringList(null), isEmpty);
    expect(JsonRead.stringList(''), isEmpty);
    expect(JsonRead.stringList([1, null, 'c']), ['1', 'c']);
  });

  test('list', () {
    int f(Map<String, dynamic> m) => JsonRead.integer(m['id']);
    expect(JsonRead.list(null, f), isEmpty);
    expect(JsonRead.list(<String, dynamic>{}, f), isEmpty);
    expect(JsonRead.list([{'id': 1}, 'junk'], f), [1]);
  });

  test('time readers', () {
    expect(JsonRead.utc('2026-10-17 05:00:00'), DateTime.utc(2026, 10, 17, 5));
    expect(JsonRead.unix(1792054800), DateTime.utc(2026, 10, 15, 9));
    expect(JsonRead.date('2026-10-17'), const LocalDate(2026, 10, 17));
    expect(JsonRead.time('09:00:00'), const HmTime(9, 0));
  });
}
