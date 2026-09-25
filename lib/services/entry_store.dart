import 'dart:math' as math;

import 'package:android_terminal_launcher/services/entry.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';

/// A numbered list of [Entry]s kept in a [LocalStore] under one key. Notes and
/// todos are two instances with different keys.
///
/// Every call reads, changes and rewrites the whole list, one call at a time:
/// commands are not awaited by the UI, so two quick `note add` lines would
/// otherwise both read the same list and one would be lost. Use one instance
/// per key.
///
/// Stored data that does not look like a list of entries throws
/// [LocalStoreException] rather than being treated as empty, so a bad value is
/// never silently overwritten.
class EntryStore {
  EntryStore({
    required this._store,
    required this._key,
    this._now = DateTime.now,
  });

  final LocalStore _store;
  final String _key;
  final DateTime Function() _now;

  Future<void> _tail = Future.value();

  /// Oldest first (ascending id).
  Future<List<Entry>> all() {
    return _exclusive(() async => List.unmodifiable((await _load()).entries));
  }

  Future<Entry?> find(int id) => _exclusive(() async {
    for (final entry in (await _load()).entries) {
      if (entry.id == id) return entry;
    }
    return null;
  });

  Future<Entry> add(String text) => _exclusive(() async {
    final doc = await _load();
    final now = _now();
    final entry = Entry(
      id: doc.nextId,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    await _save(_Document(doc.nextId + 1, [...doc.entries, entry]));
    return entry;
  });

  /// Changes the given fields of entry [id]; null if there is no such entry.
  /// A new [text] counts as an edit, a new [done] does not.
  Future<Entry?> update(int id, {String? text, bool? done}) {
    return _exclusive(() async {
      final doc = await _load();
      final index = doc.entries.indexWhere((e) => e.id == id);
      if (index == -1) return null;
      final changed = doc.entries[index].copyWith(
        text: text,
        done: done,
        updatedAt: text == null ? null : _now(),
      );
      final entries = [...doc.entries]..[index] = changed;
      await _save(_Document(doc.nextId, entries));
      return changed;
    });
  }

  /// Removes entry [id] and returns it; null if there is no such entry.
  Future<Entry?> remove(int id) => _exclusive(() async {
    final doc = await _load();
    final index = doc.entries.indexWhere((e) => e.id == id);
    if (index == -1) return null;
    final removed = doc.entries[index];
    await _save(_Document(doc.nextId, [...doc.entries]..removeAt(index)));
    return removed;
  });

  /// Removes every entry [test] accepts and returns how many there were.
  Future<int> removeWhere(bool Function(Entry entry) test) {
    return _exclusive(() async {
      final doc = await _load();
      final kept = [
        for (final entry in doc.entries)
          if (!test(entry)) entry,
      ];
      final removed = doc.entries.length - kept.length;
      if (removed > 0) await _save(_Document(doc.nextId, kept));
      return removed;
    });
  }

  /// Runs [operation] after every earlier call has finished, and keeps the
  /// queue going when one fails.
  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<_Document> _load() async {
    final raw = await _store.read(_key);
    if (raw == null) return const _Document(1, []);
    try {
      if (raw is! Map) throw const FormatException('not an object');
      final items = raw['items'];
      final nextId = raw['nextId'];
      if (items is! List || nextId is! int) {
        throw const FormatException('missing items or nextId');
      }
      final entries = [for (final item in items) Entry.fromJson(item)];
      final highest = entries.fold(0, (m, e) => math.max(m, e.id));
      // Ids never repeat, even if the stored counter was damaged.
      return _Document(math.max(nextId, highest + 1), entries);
    } on FormatException {
      throw LocalStoreException("'$_key' holds unexpected data");
    }
  }

  Future<void> _save(_Document doc) => _store.write(_key, {
    'nextId': doc.nextId,
    'items': [for (final entry in doc.entries) entry.toJson()],
  });
}

class _Document {
  const _Document(this.nextId, this.entries);

  final int nextId;
  final List<Entry> entries;
}
