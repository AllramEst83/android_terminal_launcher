import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/convert_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

Future<CommandResult> _convert(List<String> args) {
  return convertCommand.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

Future<List<String>> _lines(List<String> args) async {
  final result = await _convert(args);
  return switch (result) {
    CommandOutput(:final lines) => lines,
    CommandFailure(:final lines) => lines,
    CommandClear() => fail('unexpected clear'),
  };
}

void main() {
  test('converts and echoes both units as typed', () async {
    expect(await _lines(['5', 'km', 'mi']), ['5 km = 3.106856 mi']);
  });

  test('accepts to or in between the units', () async {
    expect(await _lines(['5', 'km', 'to', 'mi']), ['5 km = 3.106856 mi']);
    expect(await _lines(['5', 'km', 'in', 'mi']), ['5 km = 3.106856 mi']);
  });

  test('in stays a unit when it is not a connector', () async {
    expect(await _lines(['5', 'in', 'cm']), ['5 in = 12.7 cm']);
    expect(await _lines(['5', 'in', 'in', 'cm']), ['5 in = 12.7 cm']);
  });

  test('unit names are case-insensitive', () async {
    expect(await _lines(['100', 'C', 'F']), ['100 C = 212 F']);
  });

  test('the value may be an expression', () async {
    expect(await _lines(['2*3', 'km', 'm']), ['6 km = 6000 m']);
  });

  test('handles decimals and negatives', () async {
    expect(await _lines(['-40', 'c', 'f']), ['-40 c = -40 f']);
    expect(await _lines(['1,5', 'kg', 'g']), ['1.5 kg = 1500 g']);
  });

  test('units lists every kind with its units', () async {
    final lines = await _lines(['units']);

    expect(lines, hasLength(8));
    expect(lines.first, startsWith('length'));
    expect(lines.first, contains(' km '));
    expect(lines.any((l) => l.startsWith('temperature')), isTrue);
  });

  test('no arguments, or the wrong number, print the usage', () async {
    expect(await _lines([]), Messages.convertUsage);
    expect(await _lines(['5', 'km']), Messages.convertUsage);
    expect(await _lines(['5', 'km', 'mi', 'x', 'y']), Messages.convertUsage);
  });

  test('an unknown unit is named, whichever side it is on', () async {
    expect(await _lines(['5', 'parsec', 'km']), [
      Messages.convertError(Messages.unknownUnit('parsec')),
    ]);
    expect(await _lines(['5', 'km', 'furlong']), [
      Messages.convertError(Messages.unknownUnit('furlong')),
    ]);
  });

  test('units of different kinds are refused', () async {
    expect(await _lines(['5', 'km', 'kg']), [
      Messages.convertError(
        Messages.unitMismatch('km', 'length', 'kg', 'mass'),
      ),
    ]);
  });

  test('a bad value is reported', () async {
    expect(await _lines(['abc', 'km', 'mi']), [
      Messages.convertError(Messages.exprUnknownName('abc')),
    ]);
  });

  test('an overflowing result is reported', () async {
    expect(await _lines(['1e305', 'km', 'mm']), [
      Messages.convertError(Messages.exprTooLarge),
    ]);
  });

  group('suggestUnits', () {
    test('offers units of the same kind for the word being typed', () {
      final found = suggestUnits('5 km m', const []);

      expect(found, containsAll(['5 km m', '5 km mi', '5 km mm']));
      expect(found, isNot(contains('5 km km')));
      expect(found.any((s) => s.endsWith(' kg')), isFalse);
    });

    test('offers every other unit of the kind once the word is empty', () {
      final found = suggestUnits('5 km ', const []);

      expect(found, contains('5 km mi'));
      expect(found, isNot(contains('5 km km')));
      expect(found.every((s) => s.startsWith('5 km ')), isTrue);
    });

    test('keeps a connector word in place', () {
      expect(suggestUnits('5 km to m', const []), contains('5 km to mi'));
    });

    test('offers nothing before a known first unit', () {
      expect(suggestUnits('5', const []), isEmpty);
      expect(suggestUnits('5 k', const []), isEmpty);
      expect(suggestUnits('5 xyz m', const []), isEmpty);
    });
  });
}
