import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `weather <city>` for a place, `weather` for the saved home city, and
/// `weather home [<city>|clear]` to see, set or forget it.
Command weatherCommand(Weather weather) => Command(
  name: 'weather',
  description: 'Show the weather',
  usage: 'weather [city]',
  forms: [
    'weather',
    'weather <city>',
    'weather home',
    'weather home <city>',
    'weather home clear',
  ],
  examples: ['weather gothenburg', 'weather home malmö', 'weather'],
  notes: ['with no city, uses your home city', 'data from open-meteo.com'],
  run: (context) => _weather(weather, context.args),
);

Future<CommandResult> _weather(Weather weather, List<String> args) async {
  try {
    if (args.isNotEmpty && args.first.toLowerCase() == 'home') {
      return await _home(weather, args.sublist(1));
    }
    final Place place;
    if (args.isEmpty) {
      final home = await weather.home();
      if (home == null) return const CommandFailure([Messages.weatherNoHome]);
      place = home;
    } else {
      final query = args.join(' ');
      final found = await weather.find(query);
      if (found == null) {
        return CommandFailure.single(Messages.weatherNoPlace(query));
      }
      place = found;
    }
    return CommandOutput(_report(await weather.forecast(place)));
  } on NetworkException catch (error) {
    return CommandFailure.single(Messages.weatherError(error.message));
  } on LocalStoreException catch (error) {
    return CommandFailure.single(Messages.weatherError(error.message));
  }
}

Future<CommandResult> _home(Weather weather, List<String> args) async {
  if (args.isEmpty) {
    final home = await weather.home();
    return CommandOutput([
      home == null ? Messages.weatherNoHome : Messages.weatherHome(home.label),
    ]);
  }
  if (args.length == 1 && args.first.toLowerCase() == 'clear') {
    await weather.clearHome();
    return const CommandOutput([Messages.weatherHomeCleared]);
  }
  final query = args.join(' ');
  final place = await weather.find(query);
  if (place == null) {
    return CommandFailure.single(Messages.weatherNoPlace(query));
  }
  await weather.setHome(place);
  return CommandOutput([Messages.weatherHomeSet(place.label)]);
}

/// Short lines, all under about 36 characters, so nothing wraps on a phone
/// (the place name may, since it can be long).
List<String> _report(Forecast forecast) {
  final now = forecast.now;
  return [
    forecast.place.label,
    Messages.weatherNow(
      describeWeather(now.code),
      '${_whole(now.temperature)}°C',
      '${_whole(now.feelsLike)}°',
    ),
    Messages.weatherWind(
      _tenths(now.windSpeed),
      compassPoint(now.windDirection),
      now.humidity,
    ),
    for (var i = 0; i < forecast.days.length; i++)
      _day(forecast.days[i], i == 0),
  ];
}

String _day(DayForecast day, bool today) {
  final name = today ? Messages.weatherToday : _weekdays[day.date.weekday - 1];
  final rain = day.precipitation >= 0.1
      ? ' ${_tenths(day.precipitation)}mm'
      : '';
  return '${name.padRight(5)} ${_whole(day.low)}/${_whole(day.high)}° '
      '${describeWeather(day.code)}$rain';
}

/// 15.5 -> 16, -0.4 -> 0.
String _whole(double value) => formatNumber(value.roundToDouble());

/// 4.62 -> 4.6, 3.0 -> 3.
String _tenths(double value) => formatNumber((value * 10).roundToDouble() / 10);
