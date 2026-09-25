/// Small durable storage for the terminal's own data (settings, notes, …):
/// JSON values under string keys. Each feature owns its keys; nothing here
/// knows what is stored.
///
/// Values are anything `jsonEncode` accepts (maps with string keys, lists,
/// strings, numbers, bools). What [read] returns is a fresh copy, so changing
/// it never changes what is stored: call [write] to save a change.
abstract interface class LocalStore {
  /// The value last written under [key], or `null` if there is none.
  /// Throws `LocalStoreException` if the stored data cannot be read.
  Future<Object?> read(String key);

  /// Replaces whatever is stored under [key]. A [value] that is not
  /// JSON-encodable throws `JsonUnsupportedObjectError` and stores nothing.
  /// Throws `LocalStoreException` if it could not be saved.
  Future<void> write(String key, Object value);

  /// Removes [key]. Deleting a key that does not exist is not an error.
  Future<void> delete(String key);
}
