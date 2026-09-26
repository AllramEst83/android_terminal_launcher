import 'package:android_terminal_launcher/terminal/tools/alphabet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialOf', () {
    test('is the upper-case first letter', () {
      expect(initialOf('firefox'), 'F');
      expect(initialOf('Åland'), 'Å');
      expect(initialOf('  spaced'), 'S');
    });

    test('keeps Å, Ä and Ö as letters of their own', () {
      expect(initialOf('åsa'), 'Å');
      expect(initialOf('ärlig'), 'Ä');
      expect(initialOf('Örjan'), 'Ö');
    });

    test('files Æ and Ø with Ä and Ö, as Swedish does', () {
      expect(initialOf('Ægir'), 'Ä');
      expect(initialOf('Østen'), 'Ö');
    });

    test('files an accented letter under its plain one', () {
      expect(initialOf('Émile'), 'E');
      expect(initialOf('ümit'), 'U');
      expect(initialOf('Çelik'), 'C');
      expect(initialOf('Ñoño'), 'N');
      expect(initialOf('Łukasz'), 'L');
      expect(initialOf('Šimon'), 'S');
    });

    test('is # for a digit, a symbol or nothing', () {
      expect(initialOf('1Password'), '#');
      expect(initialOf('_x'), '#');
      expect(initialOf('+46 70'), '#');
      expect(initialOf(''), '#');
      expect(initialOf('   '), '#');
    });

    test('a letter of another alphabet is its own initial', () {
      expect(initialOf('Иван'), 'И');
      expect(initialOf('太郎'), '太');
    });
  });

  group('compareInitials', () {
    List<String> sorted(List<String> initials) =>
        initials.toList()..sort(compareInitials);

    test('is A to Z, then Å Ä Ö, then other alphabets, then # last', () {
      expect(sorted(['#', 'Ö', 'Z', 'Ä', 'A', 'Å', 'И', 'M']), [
        'A',
        'M',
        'Z',
        'Å',
        'Ä',
        'Ö',
        'И',
        '#',
      ]);
    });

    test('two # are equal', () {
      expect(compareInitials('#', '#'), 0);
    });
  });

  group('alphabeticalKey', () {
    test('ignores case', () {
      expect(alphabeticalKey('ANNA'), alphabeticalKey('anna'));
    });

    test('puts Å Ä Ö after every plain letter', () {
      expect(
        alphabeticalKey('zed').compareTo(alphabeticalKey('åsa')),
        lessThan(0),
      );
      expect(
        alphabeticalKey('åsa').compareTo(alphabeticalKey('ärlig')),
        lessThan(0),
      );
      expect(
        alphabeticalKey('ärlig').compareTo(alphabeticalKey('örjan')),
        lessThan(0),
      );
    });

    test('sorts an accented letter with its plain one', () {
      expect(alphabeticalKey('émile'), alphabeticalKey('emile'));
    });

    test('keeps every letter of a name, not just the first', () {
      expect(alphabeticalKey('Anna Åkesson'), 'anna {kesson');
    });
  });

  group('sortedAlphabetically', () {
    test('orders as a phone book does', () {
      final names = [
        'Örjan',
        'Zed',
        'Åsa',
        'anna',
        'Ärlig',
        'Émile',
        'Bo',
        'emil',
      ];

      expect(sortedAlphabetically(names, (n) => n), [
        'anna',
        'Bo',
        'emil',
        'Émile',
        'Zed',
        'Åsa',
        'Ärlig',
        'Örjan',
      ]);
    });

    test('keeps the given order for names that come out the same', () {
      final names = ['Anna', 'anna', 'ANNA'];

      expect(sortedAlphabetically(names, (n) => n), names);
    });

    test('does not change what it was given', () {
      final names = ['b', 'a'];

      sortedAlphabetically(names, (n) => n);

      expect(names, ['b', 'a']);
    });
  });
}
