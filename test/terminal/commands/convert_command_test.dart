import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/convert_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/in_memory_local_store.dart';

/// Unit conversions never touch rates; a fetcher that fails on any request
/// proves it.
final _neverAsked = CurrencyRates(
  fetcher: FakeHttpFetcher(),
  store: InMemoryLocalStore(),
);

Future<CommandResult> _convert(List<String> args) {
  return convertCommand(_neverAsked).run(
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

  group('money', () {
    late FakeHttpFetcher fetcher;
    late InMemoryLocalStore store;
    late DateTime now;

    setUp(() {
      fetcher = FakeHttpFetcher()
        ..route(
          'frankfurter.dev',
          File('test/fixtures/frankfurter_latest.json').readAsStringSync(),
        );
      store = InMemoryLocalStore();
      now = DateTime.utc(2026, 9, 25, 12);
    });

    Future<List<String>> money(List<String> args) async {
      final command = convertCommand(
        CurrencyRates(fetcher: fetcher, store: store, now: () => now),
      );
      final result = await command.run(
        CommandContext(
          args: args,
          apps: FakeAppRepository(),
          commands: const [],
        ),
      );
      return switch (result) {
        CommandOutput(:final lines) => lines,
        CommandFailure(:final lines) => lines,
        CommandClear() => fail('unexpected clear'),
      };
    }

    // 1 EUR = 1.1403 USD = 11.29 SEK in the saved answer.
    final hundredUsdInSek = (100 / 1.1403 * 11.29).toStringAsFixed(2);

    test('converts with cents and says which day the rates are from', () async {
      expect(await money(['100', 'usd', 'sek']), [
        '100 USD = $hundredUsdInSek SEK',
        Messages.rateNote('2026-09-25', stale: false),
      ]);
    });

    test('codes are shown in capitals however they were typed', () async {
      expect(
        (await money(['100', 'UsD', 'sEK'])).first,
        startsWith('100 USD = '),
      );
    });

    test('to and in may sit between the codes', () async {
      expect(
        (await money(['100', 'usd', 'to', 'sek'])).first,
        '100 USD = $hundredUsdInSek SEK',
      );
      expect(
        (await money(['100', 'usd', 'in', 'sek'])).first,
        '100 USD = $hundredUsdInSek SEK',
      );
    });

    test('the amount may be an expression', () async {
      expect(
        (await money(['2*50', 'usd', 'sek'])).first,
        '100 USD = $hundredUsdInSek SEK',
      );
    });

    test('zero, negative and tiny amounts are shown sensibly', () async {
      expect((await money(['0', 'usd', 'sek'])).first, '0 USD = 0.00 SEK');
      expect(
        (await money(['-100', 'usd', 'sek'])).first,
        '-100 USD = -$hundredUsdInSek SEK',
      );
      expect(
        (await money(['0.001', 'jpy', 'usd'])).first,
        '0.001 JPY = 0.00000635 USD',
      );
    });

    test('an unknown currency is named', () async {
      expect(await money(['5', 'usd', 'xyz']), [
        Messages.convertError(Messages.unknownCurrency('xyz')),
      ]);
      expect(await money(['5', 'qqq', 'sek']), [
        Messages.convertError(Messages.unknownCurrency('qqq')),
      ]);
    });

    test('a bad amount is reported before any request', () async {
      expect(await money(['abc', 'usd', 'sek']), [
        Messages.convertError(Messages.exprUnknownName('abc')),
      ]);
      expect(fetcher.requests, isEmpty);
    });

    test('a second conversion reuses the saved rates', () async {
      await money(['1', 'usd', 'sek']);
      await money(['2', 'usd', 'sek']);

      expect(fetcher.requests, hasLength(1));
    });

    test('offline, saved rates are used and labelled', () async {
      await money(['1', 'usd', 'sek']);
      now = now.add(const Duration(days: 2));
      fetcher.route('frankfurter.dev', const NetworkException('offline'));

      final lines = await money(['100', 'usd', 'sek']);

      expect(lines.first, '100 USD = $hundredUsdInSek SEK');
      expect(lines.last, Messages.rateNote('2026-09-25', stale: true));
    });

    test('offline with nothing saved says so', () async {
      fetcher.route(
        'frankfurter.dev',
        const NetworkException(
          "can't reach api.frankfurter.dev (no connection?)",
        ),
      );

      expect(await money(['100', 'usd', 'sek']), [
        Messages.convertError(
          "can't reach api.frankfurter.dev (no connection?)",
        ),
      ]);
    });

    test(
      'a unit next to a currency is an unknown unit, without a request',
      () async {
        expect(await money(['5', 'km', 'usd']), [
          Messages.convertError(Messages.unknownUnit('usd')),
        ]);
        expect(await money(['5', 'usd', 'km']), [
          Messages.convertError(Messages.unknownUnit('usd')),
        ]);
        expect(fetcher.requests, isEmpty);
      },
    );

    test(
      'words that cannot be currency codes never reach the network',
      () async {
        expect(await money(['5', 'foo', 'barbaz']), [
          Messages.convertError(Messages.unknownUnit('foo')),
        ]);
        expect(fetcher.requests, isEmpty);
      },
    );

    test('unit conversions never ask for rates', () async {
      await money(['5', 'km', 'mi']);

      expect(fetcher.requests, isEmpty);
    });

    test(
      'currencies lists the codes in phone-width rows, with the rate date',
      () async {
        final lines = await money(['currencies']);

        expect(lines.last, Messages.rateNote('2026-09-25', stale: false));
        final rows = lines.take(lines.length - 1).toList();
        expect(rows.join(' ').split(' '), containsAll(['EUR', 'USD', 'SEK']));
        for (final row in rows) {
          expect(row.length, lessThanOrEqualTo(32), reason: row);
        }
      },
    );

    test('currencies offline with nothing saved reports the failure', () async {
      fetcher.route('frankfurter.dev', const NetworkException('offline'));

      expect(await money(['currencies']), [Messages.convertError('offline')]);
    });
  });
}
