/// Plain-words descriptions of WMO weather codes, as Open-Meteo reports them.
/// Kept short: a forecast line has to fit a phone screen.
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
  71: 'Light snow',
  73: 'Snow',
  75: 'Heavy snow',
  77: 'Snow grains',
  80: 'Light showers',
  81: 'Showers',
  82: 'Heavy showers',
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
