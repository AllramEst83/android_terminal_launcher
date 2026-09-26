import 'package:android_terminal_launcher/terminal/tools/contact_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_contacts_service.dart';

final _people = [
  contact('Anna Andersson', ['mobile:0701']),
  contact('Anna', ['mobile:0702']),
  contact('Johanna Berg', ['mobile:0703']),
  contact('Åsa Öberg', ['mobile:0704']),
  contact('Bo Andersson', ['mobile:0705']),
];

List<String> _names(String query) => [
  for (final match in matchContacts(_people, query)) match.name,
];

void main() {
  group('matchContacts', () {
    test('the whole name wins over longer names that start the same', () {
      expect(_names('anna'), ['Anna']);
    });

    test('then the start of the name', () {
      expect(_names('anna a'), ['Anna Andersson']);
      expect(_names('joh'), ['Johanna Berg']);
    });

    test('then the start of any word, so a surname finds the person', () {
      expect(_names('andersson'), ['Anna Andersson', 'Bo Andersson']);
    });

    test('then anywhere in the name', () {
      expect(_names('hanna'), ['Johanna Berg']);
    });

    test('several hits in the winning tier are all returned', () {
      expect(_names('an'), ['Anna Andersson', 'Anna']);
    });

    test('ignores case, also for åäö', () {
      expect(_names('ÅSA'), ['Åsa Öberg']);
      expect(_names('öberg'), ['Åsa Öberg']);
    });

    test('extra spaces around the query do not matter', () {
      expect(_names('  bo  '), ['Bo Andersson']);
    });

    test('no match, and an empty query, match nothing', () {
      expect(_names('zzz'), isEmpty);
      expect(_names(''), isEmpty);
      expect(_names('   '), isEmpty);
    });
  });

  group('looksLikeNumber', () {
    test('digits, with the usual punctuation', () {
      for (final number in [
        '0701234567',
        '070-123 45 67',
        '+46 70 123 45 67',
        '(08) 123 456',
        '112',
      ]) {
        expect(looksLikeNumber(number), isTrue, reason: number);
      }
    });

    test('names and mixed text are not numbers', () {
      for (final text in ['anna', 'anna 1', '07x1234', 'bo2', '', '  ']) {
        expect(looksLikeNumber(text), isFalse, reason: text);
      }
    });

    test('too few digits is not a number', () {
      expect(looksLikeNumber('12'), isFalse);
      expect(looksLikeNumber('+'), isFalse);
    });

    test('a plus is only a leading one', () {
      expect(looksLikeNumber('070+123'), isFalse);
    });
  });

  test('dialable keeps digits and a leading plus', () {
    expect(dialable('+46 (0)70-123 45 67'), '+460701234567');
    expect(dialable('070 123'), '070123');
  });
}
