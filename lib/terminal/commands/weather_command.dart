import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/location_service.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/plain_flag.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `weather <city>` for a place, `weather` for where the phone is (the saved
/// home city when there is no position), and `weather home [<city>|clear]` to
/// see, set or forget that city.
Command weatherCommand(Weather weather, LocationService location) => Command(
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
  notes: [
    'with no city, uses your location',
    'or your home city, if it fails',
    '--plain: text only, this once',
    'data from SMHI where it reaches,',
    '  else open-meteo.com',
  ],
  run: (context) => _weather(weather, location, context.args),
  spinner: true,
  argSuggestions: _suggestArgs,
);

/// There is no list of cities to offer, so this only ever suggests the `home`
/// keyword and, once `home` is typed, `clear`.
List<String> _suggestArgs(String partial, List<AppInfo> apps) {
  final words = partial.split(' ');
  if (words.length == 1) return _matching(words.first, const ['home']);
  if (words.length == 2 && words.first.toLowerCase() == 'home') {
    return [
      for (final match in _matching(words[1], const ['clear'])) 'home $match',
    ];
  }
  return const [];
}

List<String> _matching(String typed, List<String> options) => [
  for (final option in options)
    if (option.startsWith(typed.toLowerCase())) option,
];

Future<CommandResult> _weather(
  Weather weather,
  LocationService location,
  List<String> allArgs,
) async {
  final (:args, :plain) = splitPlainFlag(allArgs);
  try {
    if (args.isNotEmpty && args.first.toLowerCase() == 'home') {
      return await _home(weather, args.sublist(1));
    }
    final Place place;
    // Set when the forecast is for something other than what was asked for.
    String? note;
    if (args.isEmpty) {
      final here = await location.current();
      if (here is LocationFound) {
        place = Place(
          name:
              here.name ?? Messages.weatherHere(here.latitude, here.longitude),
          region: here.name == null ? null : here.region,
          country: here.name == null ? null : here.country,
          latitude: here.latitude,
          longitude: here.longitude,
        );
      } else {
        // Where the phone is is unknown; a saved home city is the next best.
        final home = await weather.home();
        if (home == null) return CommandFailure(_whyNoLocation(here));
        place = home;
        note = Messages.weatherUsingHome;
      }
    } else {
      final query = args.join(' ');
      final found = await weather.find(query);
      if (found == null) {
        return CommandFailure.single(Messages.weatherNoPlace(query));
      }
      place = found;
    }
    final forecast = await weather.forecast(place);
    return CommandOutput([
      ?note,
      ..._report(forecast),
    ], block: plain ? null : weatherBlock(forecast, note: note));
  } on NetworkException catch (error) {
    return CommandFailure.single(Messages.weatherError(error.message));
  } on LocalStoreException catch (error) {
    return CommandFailure.single(Messages.weatherError(error.message));
  }
}

/// What to tell the user when there is no position and no home city either.
List<String> _whyNoLocation(LocationResult result) => switch (result) {
  LocationDenied(permanent: false) => [
    Messages.permissionDenied(Messages.weatherLocation),
    Messages.weatherTryCity,
    Messages.weatherSaveHome,
  ],
  LocationDenied(permanent: true) => [
    Messages.permissionOff(Messages.weatherLocation),
    ...Messages.permissionHowToGrant,
    Messages.weatherTryCity,
    Messages.weatherSaveHome,
  ],
  LocationUnavailable(:final reason) => [
    reason,
    Messages.weatherTryCity,
    Messages.weatherSaveHome,
  ],
  LocationFound() => const [],
};

Future<CommandResult> _home(Weather weather, List<String> args) async {
  if (args.isEmpty) {
    final home = await weather.home();
    return noticeOutput(
      home == null ? Messages.weatherNoHome : Messages.weatherHome(home.label),
      kind: NoticeKind.info,
    );
  }
  if (args.length == 1 && args.first.toLowerCase() == 'clear') {
    await weather.clearHome();
    return noticeOutput(Messages.weatherHomeCleared);
  }
  final query = args.join(' ');
  final place = await weather.find(query);
  if (place == null) {
    return CommandFailure.single(Messages.weatherNoPlace(query));
  }
  await weather.setHome(place);
  return noticeOutput(Messages.weatherHomeSet(place.label));
}

/// Short lines, all under about 36 characters, so nothing wraps on a phone
/// (the place name may, since it can be long).
List<String> _report(Forecast forecast) {
  final now = forecast.now;
  return [
    forecast.place.label,
    Messages.weatherNow(
      describeWeather(now.code),
      '${wholeNumber(now.temperature)}°C',
      '${wholeNumber(now.feelsLike)}°',
    ),
    Messages.weatherWind(
      oneDecimal(now.windSpeed),
      compassPoint(now.windDirection),
      now.humidity,
    ),
    for (var i = 0; i < forecast.days.length; i++)
      _day(forecast.days[i], i == 0),
    Messages.weatherSource(
      forecast.source,
      forecast.station,
      problem: forecast.problem,
    ),
  ];
}

String _day(DayForecast day, bool today) {
  final name = today ? Messages.weatherToday : _weekdays[day.date.weekday - 1];
  final rain = day.precipitation >= 0.1
      ? ' ${oneDecimal(day.precipitation)}mm'
      : '';
  return '${name.padRight(5)} ${wholeNumber(day.low)}/${wholeNumber(day.high)}° '
      '${describeWeather(day.code)}$rain';
}
