import 'dart:convert';

import 'package:android_terminal_launcher/services/http_fetcher.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';

/// Exchange rates against the euro, as published by the European Central Bank.
class Rates {
  const Rates({
    required this._perEuro,
    required this.date,
    required this.fetchedAt,
    this.stale = false,
  });

  final Map<String, double> _perEuro;

  /// The day the ECB published these rates.
  final DateTime date;

  /// When this device downloaded them.
  final DateTime fetchedAt;

  /// True when they are a saved copy because the rates could not be fetched.
  final bool stale;

  /// Currency codes we have a rate for, sorted.
  List<String> get codes => _perEuro.keys.toList()..sort();

  /// [date] as `2026-09-25`.
  String get day => _day(date);

  bool knows(String code) => _perEuro.containsKey(code.toUpperCase());

  /// [amount] converted between two known currencies, via the euro. Codes are
  /// case-insensitive; an unknown one throws [ArgumentError].
  double convert(double amount, String from, String to) {
    final fromRate = _perEuro[from.toUpperCase()];
    final toRate = _perEuro[to.toUpperCase()];
    if (fromRate == null || toRate == null) {
      throw ArgumentError('unknown currency: ${fromRate == null ? from : to}');
    }
    return amount / fromRate * toRate;
  }

  Rates copyAsStale() =>
      Rates(perEuro: _perEuro, date: date, fetchedAt: fetchedAt, stale: true);

  Map<String, Object> toJson() => {
    'date': _day(date),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'rates': _perEuro,
  };

  /// Throws [FormatException] for anything [toJson] would not have written.
  factory Rates.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('rates are not an object');
    final date = json['date'];
    final fetchedAt = json['fetchedAt'];
    final rates = json['rates'];
    if (date is! String || fetchedAt is! String || rates is! Map) {
      throw const FormatException('rates have missing fields');
    }
    final perEuro = <String, double>{};
    for (final entry in rates.entries) {
      final rate = entry.value;
      if (entry.key is! String || rate is! num || !(rate > 0)) {
        throw const FormatException('a rate is not a positive number');
      }
      perEuro[entry.key as String] = rate.toDouble();
    }
    if (perEuro.isEmpty) throw const FormatException('no rates');
    return Rates(
      perEuro: perEuro,
      date: DateTime.parse(date),
      fetchedAt: DateTime.parse(fetchedAt),
    );
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Currency rates from frankfurter.dev (ECB reference rates, no key needed),
/// kept in a [LocalStore] so conversions still work offline, with the date the
/// rates are from.
class CurrencyRates {
  CurrencyRates({
    required this._fetcher,
    required this._store,
    this._now = DateTime.now,
    this._maxAge = const Duration(hours: 6),
  });

  static const storeKey = 'currency.rates';

  final HttpFetcher _fetcher;
  final LocalStore _store;
  final DateTime Function() _now;

  /// The ECB publishes once a working day, so asking more often is pointless.
  final Duration _maxAge;

  /// Rates no older than the maximum age from the saved copy, else fresh from
  /// the network. If the network fails, the saved copy however old is returned
  /// marked [Rates.stale]; only with no saved copy does the failure propagate
  /// as a [NetworkException].
  Future<Rates> rates() async {
    final saved = await _saved();
    if (saved != null) {
      // A negative age means the clock was wrong when it was saved.
      final age = _now().difference(saved.fetchedAt);
      if (!age.isNegative && age < _maxAge) return saved;
    }
    try {
      final fresh = await _download();
      await _save(fresh);
      return fresh;
    } on NetworkException {
      if (saved != null) return saved.copyAsStale();
      rethrow;
    }
  }

  Future<Rates> _download() async {
    final body = await _fetcher.get(
      Uri.https('api.frankfurter.dev', '/v1/latest'),
    );
    try {
      final json = jsonDecode(body);
      if (json is! Map || json['base'] != 'EUR') {
        throw const FormatException('not euro-based rates');
      }
      final rates = json['rates'];
      if (rates is! Map) throw const FormatException('no rates');
      // The euro is the base, so the service leaves it out of its own list.
      return Rates.fromJson({
        'date': json['date'],
        'fetchedAt': _now().toUtc().toIso8601String(),
        'rates': {...rates, 'EUR': 1.0},
      });
    } on FormatException {
      throw const NetworkException(
        'frankfurter.dev sent an answer I could not read',
      );
    }
  }

  /// The saved copy, or null when there is none or it cannot be trusted. Rates
  /// are disposable, so unlike notes a damaged copy is simply replaced.
  Future<Rates?> _saved() async {
    try {
      final json = await _store.read(storeKey);
      return json == null ? null : Rates.fromJson(json);
    } on LocalStoreException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Best effort: failing to save must not fail a conversion that worked.
  Future<void> _save(Rates rates) async {
    try {
      await _store.write(storeKey, rates.toJson());
    } on LocalStoreException {
      // The rates are still returned; they just are not kept for offline use.
    }
  }
}
