import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/weather_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/in_memory_local_store.dart';

const _gothenburg = Place(
  name: 'Gothenburg',
  region: 'Västra Götaland County',
  country: 'Sweden',
  latitude: 57.70716,
  longitude: 11.96679,
);

class _Rig {
  _Rig() {
    fetcher
      ..route(
        'geocoding-api',
        File('test/fixtures/geocode_goteborg.json').readAsStringSync(),
      )
      ..route(
        'v1/forecast',
        File('test/fixtures/forecast_goteborg.json').readAsStringSync(),
      );
    weather = Weather(fetcher: fetcher, store: store);
    command = weatherCommand(weather);
  }

  final fetcher = FakeHttpFetcher();
  final store = InMemoryLocalStore();
  late final Weather weather;
  late final Command command;

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );

  Iterable<Uri> get geocodes =>
      fetcher.requests.where((u) => u.host.startsWith('geocoding-api'));
  Iterable<Uri> get forecasts =>
      fetcher.requests.where((u) => u.path == '/v1/forecast');
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('weather <city>', () {
    test('reports the place, now, wind, and each day', () async {
      final lines = _lines(await rig.run(['gothenburg']));

      expect(lines, [
        'Gothenburg, Västra Götaland County, Sweden',
        'Overcast, 16°C (feels 14°)',
        'wind 4.8 m/s SW · humidity 86%',
        'Today 14/17° Light drizzle 0.5mm',
        'Sat   14/17° Light drizzle 0.1mm',
        'Sun   13/18° Overcast',
        'Mon   13/17° Light drizzle 0.2mm',
      ]);
    });

    test('every line but the place name fits a phone screen', () async {
      final lines = _lines(await rig.run(['gothenburg']));

      for (final line in lines.skip(1)) {
        expect(line.length, lessThanOrEqualTo(36), reason: line);
      }
    });

    test(
      'looks the place up, then asks for its forecast by coordinates',
      () async {
        await rig.run(['gothenburg']);

        expect(rig.geocodes.single.queryParameters['name'], 'gothenburg');
        expect(rig.forecasts.single.queryParameters['latitude'], '57.70716');
        expect(rig.forecasts.single.queryParameters['longitude'], '11.96679');
      },
    );

    test('a city of several words is joined', () async {
      await rig.run(['new', 'york']);

      expect(rig.geocodes.single.queryParameters['name'], 'new york');
    });

    test(
      'a place that does not exist is reported, with no forecast asked for',
      () async {
        rig.fetcher.route('geocoding-api', '{"generationtime_ms":0.5}');

        final result = await rig.run(['zzzz']);

        expect(result, isA<CommandFailure>());
        expect(_lines(result), [Messages.weatherNoPlace('zzzz')]);
        expect(rig.forecasts, isEmpty);
      },
    );

    test('does not change the saved home', () async {
      await rig.run(['gothenburg']);

      expect(await rig.weather.home(), isNull);
    });
  });

  group('weather (no city)', () {
    test('uses the saved home, without looking it up again', () async {
      await rig.weather.setHome(_gothenburg);

      final lines = _lines(await rig.run([]));

      expect(lines.first, _gothenburg.label);
      expect(rig.geocodes, isEmpty);
      expect(rig.forecasts, hasLength(1));
    });

    test('with no home saved, says how to set one', () async {
      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.weatherNoHome]);
      expect(rig.fetcher.requests, isEmpty);
    });
  });

  group('weather home', () {
    test('sets the home city from a name and says where it is', () async {
      final result = await rig.run(['home', 'gothenburg']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [Messages.weatherHomeSet(_gothenburg.label)]);
      expect((await rig.weather.home())?.latitude, 57.70716);
    });

    test('a home city of several words is joined', () async {
      await rig.run(['home', 'new', 'york']);

      expect(rig.geocodes.single.queryParameters['name'], 'new york');
    });

    test('shows the current home', () async {
      await rig.weather.setHome(_gothenburg);

      expect(_lines(await rig.run(['home'])), [
        Messages.weatherHome(_gothenburg.label),
      ]);
    });

    test('with none set, says so as information, not as an error', () async {
      final result = await rig.run(['home']);

      expect(result, isA<CommandOutput>());
      expect(_lines(result), [Messages.weatherNoHome]);
    });

    test('clear forgets it', () async {
      await rig.weather.setHome(_gothenburg);

      final result = await rig.run(['home', 'clear']);

      expect(_lines(result), [Messages.weatherHomeCleared]);
      expect(await rig.weather.home(), isNull);
    });

    test('is matched ignoring case', () async {
      await rig.run(['HOME', 'gothenburg']);
      final result = await rig.run(['Home', 'CLEAR']);

      expect(_lines(result), [Messages.weatherHomeCleared]);
    });

    test('an unknown place changes nothing', () async {
      await rig.weather.setHome(_gothenburg);
      rig.fetcher.route('geocoding-api', '{"generationtime_ms":0.5}');

      final result = await rig.run(['home', 'zzzz']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.weatherNoPlace('zzzz')]);
      expect((await rig.weather.home())?.name, 'Gothenburg');
    });

    test('a failed save is reported', () async {
      rig.store.failure = const LocalStoreException('disk full');

      final result = await rig.run(['home', 'gothenburg']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.weatherError('disk full')]);
    });
  });

  group('failures', () {
    test('no connection is reported with the reason', () async {
      rig.fetcher.route(
        'geocoding-api',
        const NetworkException(
          "can't reach geocoding-api.open-meteo.com (no connection?)",
        ),
      );

      final result = await rig.run(['gothenburg']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.weatherError(
          "can't reach geocoding-api.open-meteo.com (no connection?)",
        ),
      ]);
    });

    test('a forecast that fails after a good lookup is reported too', () async {
      rig.fetcher.route(
        'v1/forecast',
        const NetworkException('api.open-meteo.com did not answer in time'),
      );

      final result = await rig.run(['gothenburg']);

      expect(_lines(result), [
        Messages.weatherError('api.open-meteo.com did not answer in time'),
      ]);
    });

    test('an answer it cannot read is reported', () async {
      rig.fetcher.route('v1/forecast', '{"current":{}}');

      final result = await rig.run(['gothenburg']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result).single, startsWith('weather: '));
      expect(_lines(result).single, contains('could not read'));
    });
  });

  test(
    'has no argument suggestions, since city names are the user\'s to type',
    () {
      expect(rig.command.argSuggestions, isNull);
    },
  );
}
