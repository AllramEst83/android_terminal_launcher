import 'package:android_terminal_launcher/terminal/tools/units.dart';
import 'package:flutter_test/flutter_test.dart';

double _convert(double value, String from, String to) =>
    convertUnits(value, findUnit(from)!, findUnit(to)!);

void main() {
  group('the table', () {
    test('no name belongs to two units', () {
      final names = [for (final unit in allUnits) ...unit.names];

      expect(names.toSet(), hasLength(names.length));
    });

    test('names are lowercase, so lookup can ignore case', () {
      for (final unit in allUnits) {
        for (final name in unit.names) {
          expect(name, name.toLowerCase());
        }
      }
    });

    test('every kind has at least two units to convert between', () {
      for (final kind in UnitKind.values) {
        expect(allUnits.where((u) => u.kind == kind).length, greaterThan(1));
      }
    });

    test('converting a unit to itself changes nothing', () {
      for (final unit in allUnits) {
        expect(convertUnits(12.5, unit, unit), closeTo(12.5, 1e-9));
      }
    });
  });

  group('findUnit', () {
    test('finds by any name, ignoring case', () {
      expect(findUnit('KM'), same(findUnit('kilometers')));
      expect(findUnit('Feet'), same(findUnit('ft')));
    });

    test('is null for unknown names', () {
      expect(findUnit('parsec'), isNull);
      expect(findUnit(''), isNull);
    });
  });

  group('convertUnits', () {
    test('length', () {
      expect(_convert(1, 'mi', 'km'), closeTo(1.609344, 1e-9));
      expect(_convert(5, 'km', 'mi'), closeTo(3.10685596, 1e-7));
      expect(_convert(12, 'in', 'ft'), closeTo(1, 1e-9));
    });

    test('mass', () {
      expect(_convert(1, 'kg', 'lb'), closeTo(2.2046226, 1e-6));
      expect(_convert(500, 'g', 'kg'), closeTo(0.5, 1e-9));
    });

    test('volume, including Swedish kitchen measures', () {
      expect(_convert(1, 'msk', 'ml'), closeTo(15, 1e-9));
      expect(_convert(1, 'tsk', 'ml'), closeTo(5, 1e-9));
      expect(_convert(1, 'dl', 'ml'), closeTo(100, 1e-9));
      expect(_convert(1, 'gal', 'l'), closeTo(3.785411784, 1e-9));
    });

    test('time', () {
      expect(_convert(2, 'h', 'min'), closeTo(120, 1e-9));
      expect(_convert(1, 'wk', 'd'), closeTo(7, 1e-9));
    });

    test('speed', () {
      expect(_convert(36, 'km/h', 'm/s'), closeTo(10, 1e-9));
      expect(_convert(60, 'mph', 'km/h'), closeTo(96.56064, 1e-5));
    });

    test('temperature has different zero points', () {
      expect(_convert(100, 'c', 'f'), closeTo(212, 1e-9));
      expect(_convert(32, 'f', 'c'), closeTo(0, 1e-9));
      expect(_convert(0, 'c', 'k'), closeTo(273.15, 1e-9));
      expect(_convert(-40, 'c', 'f'), closeTo(-40, 1e-9));
    });

    test('area', () {
      expect(_convert(1, 'ha', 'm2'), closeTo(10000, 1e-9));
      expect(_convert(1, 'km2', 'ha'), closeTo(100, 1e-9));
    });

    test('data: decimal and binary prefixes differ', () {
      expect(_convert(1, 'kb', 'b'), 1000);
      expect(_convert(1, 'kib', 'b'), 1024);
      expect(_convert(1, 'gb', 'mb'), 1000);
    });

    test('different kinds refuse to convert', () {
      expect(() => _convert(1, 'km', 'kg'), throwsArgumentError);
    });
  });
}
