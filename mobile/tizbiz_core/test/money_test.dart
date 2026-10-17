import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  const nb = ' ';

  group('Money.format', () {
    test('groups with NBSP and appends currency', () {
      expect(Money.format(15000000), "150${nb}000${nb}so'm");
      expect(Money.format(5000000), "50${nb}000${nb}so'm");
      expect(Money.format(0), "0${nb}so'm");
      expect(Money.format(99), "1${nb}so'm");
      expect(Money.format(49), "0${nb}so'm");
    });

    test('rounds half away from zero', () {
      expect(Money.format(5000050), "50${nb}001${nb}so'm");
    });

    test('negative and null', () {
      expect(Money.format(-1500000), "-15${nb}000${nb}so'm");
      expect(Money.format(null), '—');
    });

    test('large amounts', () {
      expect(Money.format(150000000000), "1${nb}500${nb}000${nb}000${nb}so'm");
    });

    test('options', () {
      expect(Money.format(15000000, withCurrency: false), '150${nb}000');
      expect(Money.format(15000000, separator: ' '), "150 000 so'm");
    });
  });

  test('Money.group', () {
    expect(Money.group(1234567), '1${nb}234${nb}567');
    expect(Money.group(999), '999');
    expect(Money.group(-1000), '-1${nb}000');
    expect(Money.group(0), '0');
  });

  test('toSom / fromSom', () {
    expect(Money.toSom(2000000), 20000);
    expect(Money.toSom(5000050), 50001);
    expect(Money.fromSom(50), 5000);
    expect(Money.fromSom(12.5), 1250);
  });

  test('Money.compact', () {
    expect(Money.compact(15000000), "150 ming so'm");
    expect(Money.compact(150000000), "1,5 mln so'm");
    expect(Money.compact(100000000), "1 mln so'm");
    expect(Money.compact(250000000000), "2,5 mlrd so'm");
    expect(Money.compact(95000), "950 so'm");
    expect(Money.compact(15000000, withCurrency: false), '150 ming');
    expect(Money.compact(-15000000), "-150 ming so'm");
    expect(Money.compact(99996000), "1 mln so'm");
  });

  test('Money.parseSomInput', () {
    expect(Money.parseSomInput('150 000'), 15000000);
    expect(Money.parseSomInput('150${nb}000'), 15000000);
    expect(Money.parseSomInput('150 000'), 15000000);
    expect(Money.parseSomInput('150000'), 15000000);
    expect(Money.parseSomInput('1 500,50'), 150050);
    expect(Money.parseSomInput('12.5'), 1250);
    expect(Money.parseSomInput(''), isNull);
    expect(Money.parseSomInput(null), isNull);
    expect(Money.parseSomInput('abc'), isNull);
    expect(Money.parseSomInput('1,2,3'), isNull);
    expect(Money.parseSomInput('1,234'), isNull);
  });
}
