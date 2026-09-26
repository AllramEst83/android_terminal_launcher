import 'dart:convert';

import 'package:android_terminal_launcher/services/http_fetcher.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';

/// A named place on the map.
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
  });

  final String name;

  /// County, state or the like, when the geocoder knows it.
  final String? region;
  final String? country;
  final double latitude;
  final double longitude;

  /// `Gothenburg, Västra Götaland County, Sweden`: enough to tell two places
  /// with the same name apart.
  String get label => [name, ?region, ?country].join(', ');

  Map<String, Object> toJson() => {
    'name': name,
    'region': ?region,
    'country': ?country,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Throws [FormatException] for anything [toJson] would not have written.
  factory Place.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('place is not an object');
    final name = json['name'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final region = json['region'];
    final country = json['country'];
    if (name is! String ||
        latitude is! num ||
        longitude is! num ||
        (region != null && region is! String) ||
        (country != null && country is! String)) {
      throw const FormatException('place has missing or mistyped fields');
    }
    return Place(
      name: name,
      region: region as String?,
      country: country as String?,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}

/// Weather right now. Metric: °C, m/s, mm.
class Conditions {
  const Conditions({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.code,
    required this.windSpeed,
    required this.windDirection,
    required this.precipitation,
  });

  final double temperature;
  final double feelsLike;

  /// Percent.
  final int humidity;

  /// WMO weather code; see `describeWeather`.
  final int code;
  final double windSpeed;

  /// Degrees the wind blows *from*, 0 = north.
  final int windDirection;
  final double precipitation;
}

class DayForecast {
  const DayForecast({
    required this.date,
    required this.code,
    required this.low,
    required this.high,
    required this.precipitation,
  });

  final DateTime date;
  final int code;
  final double low;
  final double high;

  /// Total for the day, mm.
  final double precipitation;
}

class Forecast {
  const Forecast({required this.place, required this.now, required this.days});

  final Place place;
  final Conditions now;

  /// Today first.
  final List<DayForecast> days;
}

/// Weather from Open-Meteo (https://open-meteo.com): free, no key. Places come
/// from its geocoding service. Also remembers one home place.
class Weather {
  Weather({required this._fetcher, required this._store, this._days = 5});

  static const homeKey = 'weather.home';

  final HttpFetcher _fetcher;
  final LocalStore _store;

  /// How many days the forecast covers, today included.
  final int _days;

  /// The best match for [name], or null when there is none. Throws
  /// [NetworkException] when the service cannot be reached or misbehaves.
  Future<Place?> find(String name) async {
    final json = await _json(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': name,
        'count': '1',
        'language': 'en',
        'format': 'json',
      }),
    );
    // No match at all is an answer without a `results` key.
    final results = json['results'];
    if (results == null) return null;
    if (results is! List) throw _unexpected;
    if (results.isEmpty) return null;
    for (final result in results) {
      try {
        return Place.fromJson({
          'name': _field(result, 'name'),
          'region': _field(result, 'admin1', optional: true),
          'country': _field(result, 'country', optional: true),
          'latitude': _field(result, 'latitude'),
          'longitude': _field(result, 'longitude'),
        });
      } on FormatException {
        continue;
      }
    }
    throw _unexpected;
  }

  Future<Forecast> forecast(Place place) async {
    final json = await _json(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '${place.latitude}',
        'longitude': '${place.longitude}',
        'current': [
          'temperature_2m',
          'apparent_temperature',
          'relative_humidity_2m',
          'precipitation',
          'weather_code',
          'wind_speed_10m',
          'wind_direction_10m',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_sum',
        ].join(','),
        'timezone': 'auto',
        'forecast_days': '$_days',
        'wind_speed_unit': 'ms',
      }),
    );
    try {
      return _parseForecast(place, json);
    } on FormatException {
      throw _unexpected;
    } on TypeError {
      throw _unexpected;
    }
  }

  Forecast _parseForecast(Place place, Map<String, Object?> json) {
    final current = json['current'] as Map<String, Object?>;
    final daily = json['daily'] as Map<String, Object?>;
    final dates = (daily['time'] as List).cast<String>();
    final codes = (daily['weather_code'] as List).cast<num>();
    final highs = (daily['temperature_2m_max'] as List).cast<num>();
    final lows = (daily['temperature_2m_min'] as List).cast<num>();
    final rain = (daily['precipitation_sum'] as List).cast<num>();
    final count = dates.length;
    if (count == 0 ||
        [codes, highs, lows, rain].any((list) => list.length != count)) {
      throw const FormatException('daily lists differ in length');
    }
    return Forecast(
      place: place,
      now: Conditions(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).round(),
        code: (current['weather_code'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        windDirection: (current['wind_direction_10m'] as num).round(),
        precipitation: (current['precipitation'] as num).toDouble(),
      ),
      days: [
        for (var i = 0; i < count; i++)
          DayForecast(
            date: DateTime.parse(dates[i]),
            code: codes[i].toInt(),
            low: lows[i].toDouble(),
            high: highs[i].toDouble(),
            precipitation: rain[i].toDouble(),
          ),
      ],
    );
  }

  /// The saved home place, or null when none is saved or it cannot be read: a
  /// damaged setting is simply "not set".
  Future<Place?> home() async {
    try {
      final json = await _store.read(homeKey);
      return json == null ? null : Place.fromJson(json);
    } on LocalStoreException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Throws [LocalStoreException] when it could not be saved.
  Future<void> setHome(Place place) => _store.write(homeKey, place.toJson());

  Future<void> clearHome() => _store.delete(homeKey);

  Future<Map<String, Object?>> _json(Uri url) async {
    final body = await _fetcher.get(url);
    try {
      final json = jsonDecode(body);
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Falls through to the error below.
    }
    throw _unexpected;
  }

  Object? _field(Object? result, String key, {bool optional = false}) {
    if (result is Map && result[key] != null) return result[key];
    if (optional) return null;
    throw const FormatException('geocoding result is missing a field');
  }

  NetworkException get _unexpected =>
      const NetworkException('open-meteo.com sent an answer I could not read');
}
