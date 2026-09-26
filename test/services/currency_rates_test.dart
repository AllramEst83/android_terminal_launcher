import 'dart:io';

import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_http_fetcher.dart';
import '../fakes/in_memory_local_store.dart';

/// A real answer from frankfurter.dev (EUR base), saved as-is.
String _realRates() =>
    File('test/fixtures/frankfurter_latest.json').readAsStringSync();

const _offline = NetworkException(
  "can't reach api.frankfurter.dev (no connection?)",
);

class _Rig {
  _Rig() {
    fetcher.route('frankfurter.dev', _realRates());
    service = CurrencyRates(fetcher: fetcher, store: store, now: () => now);
  }

  final fetcher = FakeHttpFetcher();
  final store = InMemoryLocalStore();
  DateTime now = DateTime.utc(2026, 9, 25, 12);
  late final CurrencyRates service;

  void advance(Duration by) => now = now.add(by);
}

Matcher _unreadable() => throwsA(
  isA<NetworkException>().having(
    (e) => e.message,
    'message',
    contains('could not read'),
  ),
);

void main() {
  group('fetching', () {
    test('asks frankfurter.dev for the latest rates over https', () async {
      final rig = _Rig();

      await rig.service.rates();

      final url = rig.fetcher.requests.single;
      expect(url.scheme, 'https');
      expect(url.host, 'api.frankfurter.dev');
      expect(url.path, '/v1/latest');
    });

    test(
      'reads the real answer: date, many currencies, the euro added',
      () async {
        final rates = await _Rig().service.rates();

        expect(rates.day, '2026-09-25');
        expect(rates.codes.length, greaterThan(25));
        expect(rates.codes, containsAll(['EUR', 'USD', 'SEK', 'GBP', 'JPY']));
        expect(rates.codes, orderedEquals([...rates.codes]..sort()));
        expect(rates.stale, isFalse);
      },
    );

    test('records when it was fetched', () async {
      final rig = _Rig();

      final rates = await rig.service.rates();

      expect(rates.fetchedAt.toUtc(), rig.now);
    });
  });

  group('converting', () {
    late Rates rates;
    setUp(() async => rates = await _Rig().service.rates());

    test('goes through the euro', () {
      // 1 EUR = 1.1403 USD = 11.29 SEK in the saved answer.
      expect(
        rates.convert(100, 'USD', 'SEK'),
        closeTo(100 / 1.1403 * 11.29, 1e-9),
      );
      expect(rates.convert(1, 'EUR', 'SEK'), closeTo(11.29, 1e-9));
      expect(rates.convert(11.29, 'SEK', 'EUR'), closeTo(1, 1e-9));
    });

    test('converting a currency to itself changes nothing', () {
      expect(rates.convert(42.5, 'SEK', 'SEK'), closeTo(42.5, 1e-9));
    });

    test('a round trip returns the start', () {
      final there = rates.convert(250, 'GBP', 'JPY');

      expect(rates.convert(there, 'JPY', 'GBP'), closeTo(250, 1e-9));
    });

    test('codes are case-insensitive', () {
      expect(rates.convert(10, 'usd', 'Sek'), rates.convert(10, 'USD', 'SEK'));
      expect(rates.knows('sek'), isTrue);
    });

    test('an unknown code throws and is not known', () {
      expect(rates.knows('XYZ'), isFalse);
      expect(() => rates.convert(1, 'XYZ', 'SEK'), throwsArgumentError);
      expect(() => rates.convert(1, 'SEK', 'XYZ'), throwsArgumentError);
    });
  });

  group('caching', () {
    test('a recent saved copy is used without asking the network', () async {
      final rig = _Rig();
      await rig.service.rates();
      rig.advance(const Duration(hours: 5));

      final again = await rig.service.rates();

      expect(rig.fetcher.requests, hasLength(1));
      expect(again.stale, isFalse);
    });

    test('an old copy is replaced by a fresh download', () async {
      final rig = _Rig();
      await rig.service.rates();
      rig.advance(const Duration(hours: 7));

      final again = await rig.service.rates();

      expect(rig.fetcher.requests, hasLength(2));
      expect(again.fetchedAt.toUtc(), rig.now);
    });

    test('the copy survives a restart', () async {
      final rig = _Rig();
      await rig.service.rates();

      final restarted = CurrencyRates(
        fetcher: rig.fetcher,
        store: rig.store,
        now: () => rig.now,
      );
      final rates = await restarted.rates();

      expect(rig.fetcher.requests, hasLength(1));
      expect(rates.codes, contains('SEK'));
    });

    test('a copy dated in the future is not trusted', () async {
      final rig = _Rig();
      await rig.service.rates();
      rig.now = rig.now.subtract(const Duration(days: 3));

      await rig.service.rates();

      expect(rig.fetcher.requests, hasLength(2));
    });
  });

  group('offline', () {
    test('an old saved copy is returned, marked as stale', () async {
      final rig = _Rig();
      await rig.service.rates();
      rig.advance(const Duration(days: 3));
      rig.fetcher.route('frankfurter.dev', _offline);

      final rates = await rig.service.rates();

      expect(rates.stale, isTrue);
      expect(rates.day, '2026-09-25');
      expect(rates.convert(1, 'EUR', 'SEK'), closeTo(11.29, 1e-9));
    });

    test('with no saved copy the failure is reported', () async {
      final rig = _Rig();
      rig.fetcher.route('frankfurter.dev', _offline);

      await expectLater(rig.service.rates(), throwsA(same(_offline)));
    });

    test('an unreadable answer also falls back to the saved copy', () async {
      final rig = _Rig();
      await rig.service.rates();
      rig.advance(const Duration(days: 1));
      rig.fetcher.route('frankfurter.dev', '<html>oops</html>');

      expect((await rig.service.rates()).stale, isTrue);
    });
  });

  group('unexpected answers', () {
    Future<void> expectUnreadable(String body) async {
      final rig = _Rig();
      rig.fetcher.route('frankfurter.dev', body);
      await expectLater(rig.service.rates(), _unreadable());
    }

    test('not JSON', () => expectUnreadable('<html>maintenance</html>'));
    test('not an object', () => expectUnreadable('[1,2]'));
    test(
      'rates against another base',
      () => expectUnreadable(
        '{"base":"USD","date":"2026-09-25","rates":{"SEK":9.9}}',
      ),
    );
    test(
      'no rates',
      () => expectUnreadable('{"base":"EUR","date":"2026-09-25"}'),
    );
    test(
      'rates that are not numbers',
      () => expectUnreadable(
        '{"base":"EUR","date":"2026-09-25","rates":{"SEK":"lots"}}',
      ),
    );
    test(
      'a rate of zero',
      () => expectUnreadable(
        '{"base":"EUR","date":"2026-09-25","rates":{"SEK":0}}',
      ),
    );
    test(
      'a date that is not a date',
      () =>
          expectUnreadable('{"base":"EUR","date":"soon","rates":{"SEK":9.9}}'),
    );
    test(
      'no date',
      () => expectUnreadable('{"base":"EUR","rates":{"SEK":9.9}}'),
    );

    test('whole-number rates are accepted', () async {
      final rig = _Rig();
      rig.fetcher.route(
        'frankfurter.dev',
        '{"base":"EUR","date":"2026-09-25","rates":{"XXX":2}}',
      );

      final rates = await rig.service.rates();

      expect(rates.convert(1, 'EUR', 'XXX'), 2);
    });
  });

  group('a damaged saved copy', () {
    test('is replaced rather than trusted', () async {
      final rig = _Rig();
      await rig.store.write(CurrencyRates.storeKey, 'garbage');

      final rates = await rig.service.rates();

      expect(rates.codes, contains('SEK'));
      expect(rig.fetcher.requests, hasLength(1));
      // And the replacement is a good copy.
      rig.advance(const Duration(hours: 1));
      await rig.service.rates();
      expect(rig.fetcher.requests, hasLength(1));
    });

    test('with bad rates inside is replaced too', () async {
      final rig = _Rig();
      await rig.store.write(CurrencyRates.storeKey, {
        'date': '2026-09-25',
        'fetchedAt': '2026-09-25T11:00:00.000Z',
        'rates': {'SEK': -3},
      });

      await rig.service.rates();

      expect(rig.fetcher.requests, hasLength(1));
    });
  });

  group('storage problems', () {
    test('an unreadable store is not fatal', () async {
      final rig = _Rig();
      rig.store.failure = const LocalStoreException('locked');

      final rates = await rig.service.rates();

      expect(rates.codes, contains('SEK'));
    });

    test('failing to save still returns the fresh rates', () async {
      final rig = _Rig();
      // Reads work, writes fail: rates are returned but not kept.
      final failing = _WriteFailingStore();
      final service = CurrencyRates(
        fetcher: rig.fetcher,
        store: failing,
        now: () => rig.now,
      );

      final rates = await service.rates();

      expect(rates.codes, contains('SEK'));
    });
  });
}

class _WriteFailingStore extends InMemoryLocalStore {
  @override
  Future<void> write(String key, Object value) =>
      throw const LocalStoreException('disk full');
}
