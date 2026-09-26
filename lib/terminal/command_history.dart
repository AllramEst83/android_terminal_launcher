import 'dart:math';

import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';

DateTime _systemNow() => DateTime.now();

/// One command line the user has run, with how much it counts.
class HistoryEntry {
  const HistoryEntry({
    required this.line,
    required this.score,
    required this.updated,
  });

  final String line;

  /// Uses, each worth less the longer ago it was: as it was at [updated].
  final double score;
  final DateTime updated;

  Map<String, Object> toJson() => {
    'l': line,
    's': score,
    'u': updated.millisecondsSinceEpoch,
  };

  /// Throws [FormatException] for anything [toJson] would not have written.
  factory HistoryEntry.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('entry is not an object');
    final line = json['l'];
    final score = json['s'];
    final updated = json['u'];
    if (line is! String ||
        line.trim().isEmpty ||
        score is! num ||
        !score.isFinite ||
        updated is! int) {
      throw const FormatException('entry has missing or mistyped fields');
    }
    return HistoryEntry(
      line: line,
      score: score.toDouble(),
      updated: DateTime.fromMillisecondsSinceEpoch(updated),
    );
  }
}

/// The command lines the user runs, ranked by how often and how recently, so
/// the ones in daily use are a tap away. Every use adds one to a line's score,
/// and the whole score halves every [halfLife], so last week's habit fades for
/// this week's without anything ever being counted by hand.
///
/// Saved through a [LocalStore] on every change; a damaged or unreadable save
/// is an empty history, and a save that fails is not an error (history is a
/// convenience, and never worth a failed command).
class CommandHistory {
  CommandHistory({
    required this._store,
    this._clock = _systemNow,
    this.maxEntries = 100,
    this.halfLife = const Duration(days: 14),
  });

  static const key = 'history';

  final LocalStore _store;
  final DateTime Function() _clock;

  /// The most lines kept; the lowest scoring go first.
  final int maxEntries;
  final Duration halfLife;

  final Map<String, HistoryEntry> _entries = {};

  int get length => _entries.length;

  /// Reads the saved history. Never throws.
  Future<void> load() async {
    _entries.clear();
    final Object? saved;
    try {
      saved = await _store.read(key);
    } on LocalStoreException {
      return;
    }
    if (saved is! List) return;
    for (final item in saved) {
      try {
        final entry = HistoryEntry.fromJson(item);
        _entries[entry.line] = entry;
      } on FormatException {
        // One bad entry is dropped, not the rest.
      }
    }
  }

  /// Counts one more use of [line]. The count is changed at once; the returned
  /// future is the saving, which never fails. A blank line is ignored.
  Future<void> record(String line) {
    final text = line.trim();
    if (text.isEmpty) return Future.value();
    final now = _clock();
    final before = _entries[text];
    _entries[text] = HistoryEntry(
      line: text,
      score: (before == null ? 0 : _scoreOf(before, now)) + 1,
      updated: now,
    );
    if (_entries.length > maxEntries) {
      final ranked = _ranked(now);
      for (final entry in ranked.skip(maxEntries)) {
        _entries.remove(entry.line);
      }
    }
    return _save();
  }

  /// The [count] lines that count most, best first.
  List<HistoryEntry> top(int count) =>
      _ranked(_clock()).take(count).toList(growable: false);

  /// The lines that start with [prefix] (ignoring case) and go beyond it, best
  /// first, at most [limit]: what the user may be typing.
  List<HistoryEntry> matching(String prefix, {int limit = 3}) {
    final needle = prefix.trimLeft().toLowerCase();
    if (needle.isEmpty) return const [];
    return [
      for (final entry in _ranked(_clock()))
        if (entry.line.length > needle.length &&
            entry.line.toLowerCase().startsWith(needle))
          entry,
    ].take(limit).toList(growable: false);
  }

  /// What [entry] counts for now, after fading since it was last used.
  double scoreNow(HistoryEntry entry) => _scoreOf(entry, _clock());

  /// Forgets everything, and the saved copy too.
  Future<void> clear() async {
    _entries.clear();
    try {
      await _store.delete(key);
    } on LocalStoreException {
      // Gone from memory; nothing more can be done.
    }
  }

  double _scoreOf(HistoryEntry entry, DateTime now) {
    final elapsed = now.difference(entry.updated).inMilliseconds;
    if (elapsed <= 0) return entry.score;
    return entry.score * pow(0.5, elapsed / halfLife.inMilliseconds);
  }

  List<HistoryEntry> _ranked(DateTime now) {
    final list = _entries.values.toList()
      ..sort((a, b) {
        final byScore = _scoreOf(b, now).compareTo(_scoreOf(a, now));
        if (byScore != 0) return byScore;
        final byRecency = b.updated.compareTo(a.updated);
        return byRecency != 0 ? byRecency : a.line.compareTo(b.line);
      });
    return list;
  }

  Future<void> _save() async {
    try {
      await _store.write(key, [
        for (final entry in _entries.values) entry.toJson(),
      ]);
    } on LocalStoreException {
      // Kept in memory for this run.
    }
  }
}
