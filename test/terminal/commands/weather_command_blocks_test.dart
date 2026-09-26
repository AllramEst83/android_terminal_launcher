import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/location_service.dart';
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

  Future<CommandOutput> run(List<String> args) async {
    final result = await command.run(
      CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
    );
    return result as CommandOutput;
  }
}

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  test('a forecast for a named place comes with a block', () async {
    final result = await rig.run(['gothenburg']);

    final block = result.block as WeatherBlock;
    expect(block.place, contains('Gothenburg'));
    expect(block.note, isNull);
    expect(block.now.temperature, 16);
    expect(block.days, hasLength(4));
  });

  test('the position of the phone gives one too', () async {
    rig.location.result = const LocationFound(
      latitude: 57.7,
      longitude: 11.97,
      name: 'Gothenburg',
    );

    final block = (await rig.run([])).block as WeatherBlock;

    expect(block.place, startsWith('Gothenburg'));
    expect(block.note, isNull);
  });

  test('the home fallback puts its note on the block too', () async {
    await rig.weather.setHome((await rig.weather.find('gothenburg'))!);

    final result = await rig.run([]);

    expect((result.block as WeatherBlock).note, Messages.weatherUsingHome);
    expect(result.lines.first, Messages.weatherUsingHome);
  });

  test('--plain gives the text only, wherever it is put', () async {
    for (final args in [
      ['gothenburg', '--plain'],
      ['--plain', 'gothenburg'],
    ]) {
      final result = await rig.run(args);

      expect(result.block, isNull, reason: '$args');
      expect(result.lines, isNotEmpty, reason: '$args');
    }
  });

  test('--plain is not taken for part of a city name', () async {
    await rig.run(['gothenburg', '--plain']);

    final asked = rig.fetcher.requests
        .where((u) => u.host.startsWith('geocoding-api'))
        .single;
    expect(asked.queryParameters['name'], 'gothenburg');
  });

  test('the text is the same with and without the block', () async {
    final rich = await rig.run(['gothenburg']);
    final plain = await rig.run(['gothenburg', '--plain']);

    expect(plain.lines, rich.lines);
  });

  test('the text and the block agree on every figure', () async {
    final result = await rig.run(['gothenburg']);
    final block = result.block as WeatherBlock;

    expect(
      result.lines[1],
      contains('${block.now.temperature}°C (feels ${block.now.feelsLike}°)'),
    );
    for (var i = 0; i < block.days.length; i++) {
      final day = block.days[i];
      final line = result.lines[3 + i];

      expect(line, startsWith(day.label));
      expect(line, contains('${day.low}/${day.high}°'));
      if (day.rain == null) {
        expect(line, isNot(contains('mm')));
      } else {
        expect(line, contains('${day.rain}mm'));
      }
    }
  });

  test('the home commands are notices, not forecasts', () async {
    for (final args in [
      ['home'],
      ['home', 'gothenburg'],
      ['home', 'clear'],
    ]) {
      final block = (await rig.run(args)).block;

      expect(block, isA<NoticeBlock>(), reason: '$args');
    }
  });
}
