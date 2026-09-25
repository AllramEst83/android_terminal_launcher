import 'dart:convert';

import 'package:android_terminal_launcher/services/local_store.dart';

/// Keeps each value as a JSON string, like the real store, so tests see the
/// same copy-on-read behaviour and the same rejection of unencodable values.
class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore({this.failure});

  /// Thrown by every call while set, to test how a feature handles storage
  /// errors.
  Object? failure;

  final Map<String, String> _data = {};

  /// How many times [write] succeeded, e.g. to assert nothing was saved.
  int writes = 0;

  @override
  Future<Object?> read(String key) async {
    _throwIfFailing();
    final raw = _data[key];
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> write(String key, Object value) async {
    _throwIfFailing();
    _data[key] = jsonEncode(value);
    writes++;
  }

  @override
  Future<void> delete(String key) async {
    _throwIfFailing();
    _data.remove(key);
  }

  void _throwIfFailing() {
    final error = failure;
    if (error != null) throw error;
  }
}
