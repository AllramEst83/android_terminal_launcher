import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';

/// Plain-words descriptions of WMO weather codes, as Open-Meteo reports them
/// (plus the sleet ones SMHI's symbols map to). Kept short: a forecast line has to fit a phone screen.
const _descriptions = {
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Rime fog',
  51: 'Light drizzle',
  53: 'Drizzle',
  55: 'Heavy drizzle',
  56: 'Freezing drizzle',
  57: 'Freezing drizzle',
  61: 'Light rain',
  63: 'Rain',
  65: 'Heavy rain',
  66: 'Freezing rain',
  67: 'Freezing rain',
  68: 'Light sleet',
  69: 'Heavy sleet',
  71: 'Light snow',
  73: 'Snow',
  75: 'Heavy snow',
  77: 'Snow grains',
  80: 'Light showers',
  81: 'Showers',
  82: 'Heavy showers',
  83: 'Sleet showers',
  84: 'Heavy sleet',
  85: 'Snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunder and hail',
  99: 'Thunder and hail',
};

/// What [code] means, or a placeholder naming it for a code not listed.
String describeWeather(int code) => _descriptions[code] ?? 'Weather $code';

const _points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/// The eight-point compass name for a bearing in degrees; any angle works.
String compassPoint(int degrees) {
  final index = ((degrees % 360 + 360) % 360 + 22.5) ~/ 45;
  return _points[index % 8];
}

/// The picture that goes with [code]: what the sky looks like, however it is
/// worded. A code not listed is taken for cloud, the safe middle.
WeatherKind weatherKind(int code) => switch (code) {
  0 || 1 => WeatherKind.clear,
  2 => WeatherKind.partlyCloudy,
  45 || 48 => WeatherKind.fog,
  >= 51 && <= 57 => WeatherKind.drizzle,
  >= 61 && <= 67 || >= 80 && <= 82 => WeatherKind.rain,
  >= 71 && <= 77 || 85 || 86 => WeatherKind.snow,
  // Sleet has no picture of its own: wet snow is the nearest.
  68 || 69 || 83 || 84 => WeatherKind.snow,
  >= 95 && <= 99 => WeatherKind.thunder,
  _ => WeatherKind.cloudy,
};

/// 15.5 -> 16, -0.4 -> 0.
String wholeNumber(double value) => formatNumber(value.roundToDouble());

/// 4.62 -> 4.6, 3.0 -> 3.
String oneDecimal(double value) =>
    formatNumber((value * 10).roundToDouble() / 10);
