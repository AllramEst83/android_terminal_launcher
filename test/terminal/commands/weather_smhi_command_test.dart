import 'dart:io';

import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/smhi.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/weather_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/fake_location_service.dart';
import '../../fakes/in_memory_local_store.dart';

String _fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

/// The whole way from the command to SMHI's real answers, with only the
/// network faked.
Future<CommandOutput> _run(FakeHttpFetcher fetcher, List<String> args) async {
  final weather = Weather(
    fetcher: fetcher,
    store: InMemoryLocalStore(),
    preferred: Smhi(
      fetcher: fetcher,
      clock: () => DateTime.utc(2026, 9, 26, 15, 50),
    ),
  );
  final result = await weatherCommand(weather, FakeLocationService()).run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
  return result as CommandOutput;
}

FakeHttpFetcher _network() => FakeHttpFetcher()
  ..route('geocoding-api', _fixture('geocode_goteborg'))
  ..route('v1/forecast', _fixture('forecast_goteborg'))
  ..route('metfcst', _fixture('smhi_forecast_goteborg'))
  ..route('station-set/all', _fixture('smhi_obs_temperature'))
  ..route('parameter/4/station/71420', _fixture('smhi_obs_wind'))
  ..route('parameter/3/station/71420', _fixture('smhi_obs_direction'))
  ..route('parameter/6/station/71420', _fixture('smhi_obs_humidity'))
  ..route('parameter/1/station/71420', _fixture('smhi_obs_temperature_day'))
  ..route('parameter/7/station/71420', _fixture('smhi_obs_rain_day'));

void main() {
  test('reports SMHI\'s figures and credits SMHI and the station', () async {
    final result = await _run(_network(), ['gothenburg']);

    expect(result.lines, [
      'Gothenburg, Västra Götaland County, Sweden',
      'Clear sky, 16°C (feels 13°)',
      'wind 3.6 m/s W · humidity 60%',
      'Today 14/16° Clear sky',
      'Sun   13/18° Clear sky',
      'Mon   13/16° Overcast 0.7mm',
      'Tue   10/14° Overcast 0.7mm',
      'Wed   13/20° Overcast',
      'SMHI, measured at Göteborg A, 2 km',
    ]);
  });

  test('the card carries the same credit', () async {
    final result = await _run(_network(), ['gothenburg']);

    final card = result.block! as WeatherBlock;
    expect(card.source, 'SMHI, measured at Göteborg A, 2 km');
    expect(card.now.temperature, 16);
    expect(card.days, hasLength(5));
  });

  test('--plain still credits it', () async {
    final result = await _run(_network(), ['gothenburg', '--plain']);

    expect(result.block, isNull);
    expect(result.lines.last, 'SMHI, measured at Göteborg A, 2 km');
  });

  test(
    'outside SMHI\'s area the same command gives Open-Meteo\'s, credited',
    () async {
      final fetcher = _network()
        ..route(
          'metfcst',
          const NetworkException(
            'opendata-download-metfcst.smhi.se answered with status 404',
            statusCode: 404,
          ),
        );

      final result = await _run(fetcher, ['gothenburg']);

      expect(result.lines.last, 'Open-Meteo');
      expect((result.block! as WeatherBlock).source, 'Open-Meteo');
      expect(result.lines[1], 'Overcast, 16°C (feels 14°)');
    },
  );

  test(
    'when SMHI is broken, not just out of reach, the report says so',
    () async {
      final fetcher = _network()
        ..route(
          'metfcst',
          const NetworkException(
            'opendata-download-metfcst.smhi.se did not answer in time',
          ),
        );

      final result = await _run(fetcher, ['gothenburg']);

      const credit =
          'Open-Meteo (SMHI failed: opendata-download-metfcst.smhi.se '
          'did not answer in time)';
      expect(result.lines.last, credit);
      expect((result.block! as WeatherBlock).source, credit);
      expect(result.lines[1], 'Overcast, 16°C (feels 14°)');
    },
  );

  test('with both down it is one error line, as before', () async {
    final fetcher = _network()
      ..route('metfcst', const NetworkException('smhi is down'))
      ..route('v1/forecast', const NetworkException('open-meteo is down'));

    final result =
        await weatherCommand(
          Weather(
            fetcher: fetcher,
            store: InMemoryLocalStore(),
            preferred: Smhi(fetcher: fetcher),
          ),
          FakeLocationService(),
        ).run(
          CommandContext(
            args: ['gothenburg'],
            apps: FakeAppRepository(),
            commands: const [],
          ),
        );

    expect((result as CommandFailure).lines, ['weather: open-meteo is down']);
  });
}
