import 'package:test/test.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

void main() {
  test('normalize', () {
    for (final input in ['+998 90 123 45 67', '998901234567', '901234567', '(90) 123-45-67', '8 90 123 45 67']) {
      expect(Phone.normalize(input), '+998901234567', reason: input);
    }
    expect(Phone.normalize('12345'), isNull);
    expect(Phone.normalize(null), isNull);
    expect(Phone.normalize(''), isNull);
  });

  test('isValid', () {
    expect(Phone.isValid('901234567'), isTrue);
    expect(Phone.isValid('+998901234567'), isTrue);
    expect(Phone.isValid('12345678'), isFalse);
    expect(Phone.isValid('+7 901 234 56 78'), isFalse);
    expect(Phone.isValid(null), isFalse);
  });

  test('format / formatLocal', () {
    expect(Phone.format('+998901234567'), '+998 90 123 45 67');
    expect(Phone.format('abc'), 'abc');
    expect(Phone.format('  abc '), 'abc');
    expect(Phone.formatLocal('+998901234567'), '90 123 45 67');
  });

  test('formatPartial', () {
    const cases = {
      '9': '9',
      '90': '90',
      '901': '90 1',
      '90123': '90 123',
      '9012345': '90 123 45',
      '901234567': '90 123 45 67',
      '+998901234567': '90 123 45 67',
      '9012345678': '90 123 45 67',
      '': '',
    };
    cases.forEach((input, expected) => expect(Phone.formatPartial(input), expected, reason: input));
  });

  test('mask / telUri', () {
    expect(Phone.mask('+998901234567'), '+998 90 *** ** 67');
    expect(Phone.telUri('90 123 45 67').toString(), 'tel:+998901234567');
    expect(Phone.telUri('123'), isNull);
  });
}
