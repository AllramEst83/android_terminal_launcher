import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/weather_text.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Less than this much rain in a day is not worth a mention.
const _rainThreshold = 0.1;

/// [forecast] as a [WeatherBlock]: the same figures the text report gives,
/// rounded the same way, with a picture kind for the sky. [note] says the
/// forecast is for something other than what was asked.
WeatherBlock weatherBlock(Forecast forecast, {String? note}) {
  final now = forecast.now;
  return WeatherBlock(
    place: forecast.place.label,
    note: note,
    source: Messages.weatherSource(
      forecast.source,
      forecast.station,
      problem: forecast.problem,
    ),
    now: WeatherNow(
      kind: weatherKind(now.code),
      description: describeWeather(now.code),
      temperature: now.temperature.round(),
      feelsLike: now.feelsLike.round(),
      windSpeed: oneDecimal(now.windSpeed),
      windPoint: compassPoint(now.windDirection),
      humidity: now.humidity,
    ),
    days: [
      for (var i = 0; i < forecast.days.length; i++)
        _day(forecast.days[i], today: i == 0),
    ],
  );
}

WeatherDay _day(DayForecast day, {required bool today}) => WeatherDay(
  label: today ? Messages.weatherToday : _weekdays[day.date.weekday - 1],
  kind: weatherKind(day.code),
  description: describeWeather(day.code),
  low: day.low.round(),
  high: day.high.round(),
  rain: day.precipitation >= _rainThreshold
      ? oneDecimal(day.precipitation)
      : null,
);
