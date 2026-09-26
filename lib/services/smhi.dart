import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:android_terminal_launcher/services/http_fetcher.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/weather.dart';

DateTime _systemNow() => DateTime.now();

const _forecastBase =
    'https://opendata-download-metfcst.smhi.se/api/category/snow1g/version/1';
const _observationBase =
    'https://opendata-download-metobs.smhi.se/api/version/1.0';

// SMHI's observation parameters.
const _temperature = 1;
const _windDirection = 3;
const _windSpeed = 4;
const _humidity = 6;
const _rain = 7;

/// Older than this, a reading says nothing about now.
const _maxAge = Duration(hours: 2);

/// Hours of the day a day's symbol is taken from: the day, not the small hours.
const _dayStart = 6;
const _dayEnd = 21;

/// This much rain in a day makes the day's symbol a wet one, even if most of the
/// hours were dry.
const _wetDayMm = 1.0;

/// Weather from SMHI (https://opendata.smhi.se), the Swedish weather service:
/// its point forecast (a 2.5 km model over the Nordic countries and beyond)
/// for the days ahead, and the nearest weather station's measurements for the
/// current conditions and for what has already happened today. Free, no key;
/// the data is CC BY, so a report must say where it is from ([Forecast.source]).
///
/// Anywhere the forecast does not reach (New York, Reykjavik) SMHI answers 404
/// and this throws a [NetworkException], which `Weather` takes as the cue for
/// the fallback. The measurements are a bonus: if any of them cannot be had,
/// the forecast's own figures for the current hour stand in.
class Smhi implements ForecastSource {
  Smhi({
    required this._fetcher,
    this._days = 5,
    this._clock = _systemNow,
    this._maxStationKm = 30,
  });

  final HttpFetcher _fetcher;

  /// How many days the forecast covers, today included.
  final int _days;
  final DateTime Function() _clock;

  /// A station further away than this says nothing about the place.
  final double _maxStationKm;

  @override
  Future<Forecast> forecast(Place place) async {
    final now = _clock().toUtc();
    // Started first and never throwing, so it runs beside the forecast.
    final measured = _measure(place, now);
    final url = Uri.parse(
      '$_forecastBase/geotype/point'
      '/lon/${place.longitude.toStringAsFixed(4)}'
      '/lat/${place.latitude.toStringAsFixed(4)}/data.json',
    );
    final String body;
    try {
      body = await _fetcher.get(url);
    } on NetworkException {
      // Not waited for: the measurements are of no use without a forecast, and
      // for a place SMHI does not cover this is the normal path.
      unawaited(measured);
      rethrow;
    }
    final observed = await measured;
    try {
      return _build(place, _points(jsonDecode(body)), observed, now);
    } on FormatException catch (error) {
      throw _unexpected(error.message);
    } on TypeError catch (error) {
      throw _unexpected(error.toString().split('\n').first);
    }
  }

  /// [detail] says what was wrong, so a failure on a phone can be told from
  /// one that was never going to happen.
  NetworkException _unexpected(String detail) =>
      NetworkException('smhi.se sent an answer I could not read ($detail)');

  Forecast _build(
    Place place,
    List<_Point> points,
    _Observed? observed,
    DateTime now,
  ) {
    final today = _dateOf(swedishClock(now));
    final nearest = points.reduce(
      (a, b) => (a.time.difference(now)).abs() <= (b.time.difference(now)).abs()
          ? a
          : b,
    );
    final data = nearest.data;
    final temperature =
        observed?.temperature ?? _number(data['air_temperature']);
    final windSpeed = observed?.windSpeed ?? _number(data['wind_speed']);
    final windDirection =
        observed?.windDirection ?? _number(data['wind_from_direction']);
    final humidity = observed?.humidity ?? _number(data['relative_humidity']);

    final days = <DayForecast>[];
    final dates = {
      for (final point in points) _dateOf(swedishClock(point.time)),
    }.where((date) => !date.isBefore(today)).toList()..sort();
    for (final date in dates.take(_days)) {
      final day = _day(date, points, isToday: date == today, observed);
      if (day != null) days.add(day);
    }
    if (days.isEmpty) throw const FormatException('no days in the forecast');

    return Forecast(
      place: place,
      source: 'SMHI',
      station: observed == null
          ? null
          : '${observed.station}, ${observed.distanceKm.round()} km',
      now: Conditions(
        temperature: temperature,
        feelsLike: apparentTemperature(
          temperature: temperature,
          humidity: humidity,
          windSpeed: windSpeed,
        ),
        humidity: humidity.round(),
        code: smhiToWmo(_number(data['symbol_code']).round()),
        windSpeed: windSpeed,
        windDirection: windDirection.round(),
        precipitation: _number(data['precipitation_amount_mean'], or: 0),
      ),
      days: days,
    );
  }

  DayForecast? _day(
    DateTime date,
    List<_Point> points,
    _Observed? observed, {
    required bool isToday,
  }) {
    // Temperatures are readings at an instant: they belong to the day they
    // were taken. Rain and symbols describe the hours before that instant, so
    // they belong to the day the middle of those hours falls on.
    final temperatures = [
      for (final point in points)
        if (_dateOf(swedishClock(point.time)) == date)
          ?_numberOrNull(point.data['air_temperature']),
      // What has already happened today, which the forecast no longer holds.
      if (isToday) ...?observed?.todayTemperatures,
    ];
    if (temperatures.isEmpty) return null;
    final inDay = [
      for (final point in points)
        if (_dateOf(swedishClock(point.middle)) == date) point,
    ];
    final rain =
        inDay.fold<double>(
          0,
          (sum, point) =>
              sum + _number(point.data['precipitation_amount_mean'], or: 0),
        ) +
        (isToday ? (observed?.todayRain ?? 0) : 0);
    final daytime = [
      for (final point in inDay)
        if (swedishClock(point.middle).hour >= _dayStart &&
            swedishClock(point.middle).hour <= _dayEnd)
          point,
    ];
    final symbols = [
      for (final point in daytime.isEmpty ? inDay : daytime)
        smhiToWmo(_number(point.data['symbol_code'], or: 3).round()),
    ];
    return DayForecast(
      date: date,
      code: _representative(symbols, wet: rain >= _wetDayMm),
      low: temperatures.reduce(min),
      high: temperatures.reduce(max),
      precipitation: rain,
    );
  }

  /// The day's weather code: the one that came up most often (the more severe
  /// one when tied), but among the wet ones if the day was wet overall, so an
  /// hour of clear sky between showers does not turn a rainy day sunny. With no
  /// hours to go on, the sky is taken for overcast.
  int _representative(List<int> codes, {required bool wet}) {
    if (codes.isEmpty) return 3;
    final wetCodes = codes.where(_isWet).toList();
    final pool = wet && wetCodes.isNotEmpty ? wetCodes : codes;
    final counts = <int, int>{};
    for (final code in pool) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
    final best = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : b.key.compareTo(a.key);
      });
    return best.first.key;
  }

  /// Rain, sleet, snow or thunder, as WMO codes.
  bool _isWet(int code) => code >= 51;

  List<_Point> _points(Object? json) {
    final series = (json as Map<String, Object?>)['timeSeries'] as List;
    final points = [
      for (final entry in series) _Point.parse(entry as Map<String, Object?>),
    ];
    if (points.isEmpty) throw const FormatException('empty time series');
    return points;
  }

  /// The nearest weather station's measurements, or null if there is none near
  /// enough or anything about them could not be had. Never throws.
  Future<_Observed?> _measure(Place place, DateTime now) async {
    try {
      final all = await _read(
        '$_observationBase/parameter/$_temperature/station-set/all'
        '/period/latest-hour/data.json',
      );
      _Station? best;
      for (final entry
          in (all['station'] as List).cast<Map<String, Object?>>()) {
        final reading = _latest(entry['value'], now);
        if (reading == null) continue;
        final station = _Station(
          key: '${entry['key']}',
          name: entry['name'] as String,
          km: distanceKm(
            place.latitude,
            place.longitude,
            (entry['latitude'] as num).toDouble(),
            (entry['longitude'] as num).toDouble(),
          ),
          temperature: reading,
        );
        if (best == null || station.km < best.km) best = station;
      }
      if (best == null || best.km > _maxStationKm) return null;

      final key = best.key;
      String path(int parameter, String period) =>
          '$_observationBase/parameter/$parameter/station/$key'
          '/period/$period/data.json';
      final results = await Future.wait([
        _series(path(_windSpeed, 'latest-hour')),
        _series(path(_windDirection, 'latest-hour')),
        _series(path(_humidity, 'latest-hour')),
        _series(path(_temperature, 'latest-day')),
        _series(path(_rain, 'latest-day')),
      ]);
      final today = _dateOf(swedishClock(now));
      List<double> sinceMidnight(List<_Reading> series) => [
        for (final reading in series)
          if (_dateOf(swedishClock(reading.time)) == today) reading.value,
      ];
      double? fresh(List<_Reading> series) {
        final last = series.isEmpty ? null : series.last;
        return last != null && now.difference(last.time) <= _maxAge
            ? last.value
            : null;
      }

      final rainToday = sinceMidnight(results[4]);
      return _Observed(
        station: best.name,
        distanceKm: best.km,
        temperature: best.temperature,
        windSpeed: fresh(results[0]),
        windDirection: fresh(results[1]),
        humidity: fresh(results[2]),
        todayTemperatures: sinceMidnight(results[3]),
        todayRain: rainToday.isEmpty ? null : rainToday.reduce((a, b) => a + b),
      );
    } on NetworkException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// One station's readings, oldest first; empty if they could not be had.
  Future<List<_Reading>> _series(String url) async {
    try {
      final json = await _read(url);
      return [
        for (final entry
            in (json['value'] as List).cast<Map<String, Object?>>())
          ?_Reading.tryParse(entry),
      ]..sort((a, b) => a.time.compareTo(b.time));
    } on NetworkException {
      return const [];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  /// The newest value in [values] if it is recent enough.
  double? _latest(Object? values, DateTime now) {
    final readings = [
      for (final entry in (values as List).cast<Map<String, Object?>>())
        ?_Reading.tryParse(entry),
    ];
    if (readings.isEmpty) return null;
    readings.sort((a, b) => a.time.compareTo(b.time));
    final last = readings.last;
    return now.difference(last.time) <= _maxAge ? last.value : null;
  }

  Future<Map<String, Object?>> _read(String url) async {
    final json = jsonDecode(await _fetcher.get(Uri.parse(url)));
    if (json is Map<String, Object?>) return json;
    throw const FormatException('not an object');
  }
}

class _Point {
  const _Point(this.time, this.start, this.data);

  factory _Point.parse(Map<String, Object?> entry) {
    final time = DateTime.parse(entry['time'] as String).toUtc();
    final startText = entry['intervalParametersStartTime'] as String?;
    return _Point(
      time,
      startText == null ? time : DateTime.parse(startText).toUtc(),
      entry['data'] as Map<String, Object?>,
    );
  }

  /// When the values were valid, and when the interval they cover began (the
  /// step is an hour, then three, six and twelve as the days go on).
  final DateTime time;
  final DateTime start;
  final Map<String, Object?> data;

  DateTime get middle => start.add(time.difference(start) ~/ 2);
}

class _Station {
  const _Station({
    required this.key,
    required this.name,
    required this.km,
    required this.temperature,
  });

  final String key;
  final String name;
  final double km;
  final double temperature;
}

class _Reading {
  const _Reading(this.time, this.value);

  /// Null for a reading with no usable value, which some stations report.
  static _Reading? tryParse(Map<String, Object?> entry) {
    final value = _numberOrNull(entry['value']);
    final date = entry['date'];
    if (value == null || date is! int) return null;
    return _Reading(
      DateTime.fromMillisecondsSinceEpoch(date, isUtc: true),
      value,
    );
  }

  final DateTime time;
  final double value;
}

class _Observed {
  const _Observed({
    required this.station,
    required this.distanceKm,
    required this.temperature,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.todayTemperatures = const [],
    this.todayRain,
  });

  final String station;
  final double distanceKm;
  final double temperature;
  final double? windSpeed;
  final double? windDirection;
  final double? humidity;

  /// Every reading since midnight, for today's low and high.
  final List<double> todayTemperatures;

  /// Millimetres since midnight, if the station measures rain.
  final double? todayRain;
}

/// A number from JSON, or from the text SMHI's observations put numbers in.
double? _numberOrNull(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

/// [value] as a number; [or] if there is none, and a [FormatException] if there
/// is none and no fallback.
double _number(Object? value, {double? or}) {
  final number = _numberOrNull(value);
  if (number != null) return number;
  if (or != null) return or;
  throw const FormatException('a number is missing');
}

DateTime _dateOf(DateTime clock) =>
    DateTime.utc(clock.year, clock.month, clock.day);

/// The wall clock in Sweden (central European time, summer time from the last
/// Sunday of March to the last Sunday of October, both at 01:00 UTC) for a UTC
/// instant, as a [DateTime] (marked UTC only so the phone's own daylight-saving
/// rules cannot touch it) whose fields read as that clock. Computed
/// here, not taken from the phone, so a day is the same day wherever the phone
/// is and in tests.
DateTime swedishClock(DateTime utc) {
  final instant = utc.toUtc();
  final summerStarts = _lastSunday(
    instant.year,
    DateTime.march,
  ).add(const Duration(hours: 1));
  final summerEnds = _lastSunday(
    instant.year,
    DateTime.october,
  ).add(const Duration(hours: 1));
  final summer =
      !instant.isBefore(summerStarts) && instant.isBefore(summerEnds);
  final local = instant.add(Duration(hours: summer ? 2 : 1));
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );
}

DateTime _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.subtract(Duration(days: last.weekday % 7));
}

/// What it feels like, in °C (the Australian Bureau of Meteorology's apparent
/// temperature, which is what Open-Meteo reported): warmer when humid, cooler
/// in wind. [humidity] in percent, [windSpeed] in m/s. SMHI publishes no such
/// figure.
double apparentTemperature({
  required double temperature,
  required double humidity,
  required double windSpeed,
}) {
  final vapour =
      humidity / 100 * 6.105 * exp(17.27 * temperature / (237.7 + temperature));
  return temperature + 0.33 * vapour - 0.70 * windSpeed - 4.00;
}

/// The great-circle distance between two points, in kilometres.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const radians = pi / 180;
  final a =
      pow(sin((lat2 - lat1) * radians / 2), 2) +
      cos(lat1 * radians) *
          cos(lat2 * radians) *
          pow(sin((lon2 - lon1) * radians / 2), 2);
  return 2 * 6371 * asin(sqrt(a));
}

/// SMHI's weather symbol (`Wsymb2`, 1 to 27) as the WMO code the rest of the
/// app speaks. A symbol it does not know is taken for overcast.
int smhiToWmo(int symbol) => switch (symbol) {
  1 => 0, // clear sky
  2 => 1, // nearly clear sky
  3 || 4 => 2, // variable cloudiness, half clear
  5 || 6 => 3, // cloudy, overcast
  7 => 45, // fog
  8 => 80, // light rain showers
  9 => 81,
  10 => 82,
  11 || 21 => 95, // thunder
  12 || 13 => 83, // light and moderate sleet showers
  14 => 84,
  15 || 16 => 85, // snow showers
  17 => 86,
  18 => 61, // light rain
  19 => 63,
  20 => 65,
  22 || 23 => 68, // light and moderate sleet
  24 => 69,
  25 => 71, // light snowfall
  26 => 73,
  27 => 75,
  _ => 3,
};
