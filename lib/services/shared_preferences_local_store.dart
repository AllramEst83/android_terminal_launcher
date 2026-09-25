import 'dart:convert';

import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [LocalStore] on `shared_preferences`, each value kept as one JSON string.
/// This is the only file that knows about the package; swapping it (for a
/// database, say) must touch nothing else.
///
/// Uses the async API, which always reads from disk, so a value is never stale.
/// That suits notes and settings; it is not meant for hot paths.
class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<Object?> read(String key) async {
    final String? raw;
    try {
      raw = await _preferences.getString(key);
    } on PlatformException catch (error) {
      throw LocalStoreException(
        "could not read '$key': ${error.message ?? error.code}",
      );
    }
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw LocalStoreException("'$key' holds unreadable data");
    }
  }

  @override
  Future<void> write(String key, Object value) async {
    // Encoded first so an unencodable value fails before anything is stored.
    final encoded = jsonEncode(value);
    try {
      await _preferences.setString(key, encoded);
    } on PlatformException catch (error) {
      throw LocalStoreException(
        "could not save '$key': ${error.message ?? error.code}",
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _preferences.remove(key);
    } on PlatformException catch (error) {
      throw LocalStoreException(
        "could not delete '$key': ${error.message ?? error.code}",
      );
    }
  }
}
