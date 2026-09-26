import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/location_service.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/weather_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/fake_location_service.dart';
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
    command = weatherCommand(weather, location);
  }

  final fetcher = FakeHttpFetcher();
  final store = InMemoryLocalStore();
  final location = FakeLocationService();
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
  CommandClear() || CommandAskSecret() => fail('unexpected clear'),
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
        'Open-Meteo',
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
    test('uses where the phone is, by coordinates', () async {
      rig.location.result = const LocationFound(
        latitude: 57.7,
        longitude: 11.97,
      );

      final lines = _lines(await rig.run([]));

      expect(lines.first, Messages.weatherHere(57.7, 11.97));
      expect(rig.geocodes, isEmpty);
      expect(rig.forecasts.single.queryParameters['latitude'], '57.7');
      expect(rig.forecasts.single.queryParameters['longitude'], '11.97');
    });

    test('names the place when Android could', () async {
      rig.location.result = const LocationFound(
        latitude: 57.7,
        longitude: 11.97,
        name: 'Gothenburg',
        region: 'Västra Götaland County',
        country: 'Sweden',
      );

      final lines = _lines(await rig.run([]));

      expect(lines.first, 'Gothenburg, Västra Götaland County, Sweden');
      expect(rig.forecasts.single.queryParameters['latitude'], '57.7');
    });

    test('a region with no town is not shown on its own', () async {
      rig.location.result = const LocationFound(
        latitude: 57.7,
        longitude: 11.97,
        region: 'Västra Götaland County',
        country: 'Sweden',
      );

      final lines = _lines(await rig.run([]));

      expect(lines.first, Messages.weatherHere(57.7, 11.97));
    });

    test('the position line is short enough for a phone', () {
      expect(
        Messages.weatherHere(-57.71234, -111.96679).length,
        lessThanOrEqualTo(36),
      );
    });

    test('prefers the position to a saved home', () async {
      await rig.weather.setHome(_gothenburg);
      rig.location.result = const LocationFound(latitude: 1, longitude: 2);

      final lines = _lines(await rig.run([]));

      expect(lines.first, Messages.weatherHere(1, 2));
      expect(rig.forecasts.single.queryParameters['latitude'], '1.0');
    });

    test('a city is never a reason to ask for the location', () async {
      await rig.run(['gothenburg']);
      await rig.run(['home', 'gothenburg']);

      expect(rig.location.calls, 0);
    });

    for (final MapEntry(key: why, value: failed) in <String, LocationResult>{
      'denied': const LocationDenied(permanent: false),
      'permanently denied': const LocationDenied(permanent: true),
      'unavailable': const LocationUnavailable('no location fix'),
    }.entries) {
      test('falls back to the saved home when $why', () async {
        await rig.weather.setHome(_gothenburg);
        rig.location.result = failed;

        final result = await rig.run([]);

        expect(result, isA<CommandOutput>());
        expect(_lines(result).first, Messages.weatherUsingHome);
        expect(_lines(result)[1], _gothenburg.label);
        expect(rig.geocodes, isEmpty);
        expect(rig.forecasts, hasLength(1));
      });
    }

    test('denied with no home: says so and offers a city', () async {
      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.permissionDenied(Messages.weatherLocation),
        Messages.weatherTryCity,
        Messages.weatherSaveHome,
      ]);
      expect(rig.fetcher.requests, isEmpty);
    });

    test('permanently denied: says where to turn it on', () async {
      rig.location.result = const LocationDenied(permanent: true);

      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.permissionOff(Messages.weatherLocation),
        ...Messages.permissionHowToGrant,
        Messages.weatherTryCity,
        Messages.weatherSaveHome,
      ]);
      expect(rig.fetcher.requests, isEmpty);
    });

    test('no fix with no home: gives the reason', () async {
      rig.location.result = const LocationUnavailable(
        'location is switched off in Android',
      );

      final result = await rig.run([]);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        'location is switched off in Android',
        Messages.weatherTryCity,
        Messages.weatherSaveHome,
      ]);
    });

    test('every failure line fits a phone screen', () async {
      for (final failed in <LocationResult>[
        const LocationDenied(permanent: false),
        const LocationDenied(permanent: true),
        const LocationUnavailable('location is switched off in Android'),
      ]) {
        rig.location.result = failed;
        for (final line in _lines(await rig.run([]))) {
          expect(line.length, lessThanOrEqualTo(36), reason: line);
        }
      }
    });

    test('a forecast failure at the found position is reported', () async {
      rig.location.result = const LocationFound(latitude: 1, longitude: 2);
      rig.fetcher.route(
        'v1/forecast',
        const NetworkException('api.open-meteo.com did not answer in time'),
      );

      final result = await rig.run([]);

      expect(_lines(result), [
        Messages.weatherError('api.open-meteo.com did not answer in time'),
      ]);
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

  group('argument suggestions', () {
    // There is no list of cities to offer, so only the fixed `home`/`clear`
    // keywords are ever suggested.
    test('offers "home" for an empty or matching first word', () {
      expect(rig.command.argSuggestions!('', const []), ['home']);
      expect(rig.command.argSuggestions!('ho', const []), ['home']);
    });

    test('a city name is the user\'s to type: nothing is suggested', () {
      expect(rig.command.argSuggestions!('goth', const []), isEmpty);
    });

    test('offers "clear" once "home " is typed', () {
      expect(rig.command.argSuggestions!('home ', const []), ['home clear']);
      expect(rig.command.argSuggestions!('home cl', const []), ['home clear']);
    });

    test('a home city name is also the user\'s to type', () {
      expect(rig.command.argSuggestions!('home malm', const []), isEmpty);
    });
  });
}
