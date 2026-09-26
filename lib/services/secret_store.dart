/// Storage for secrets (passwords), kept encrypted by the platform. Unlike
/// `LocalStore` it holds plain strings and is never used for settings or
/// notes: anything that is not a secret belongs there.
///
/// Every method throws `LocalStoreException` if the platform refuses.
abstract interface class SecretStore {
  /// The value under [key], or null if there is none.
  Future<String?> read(String key);

  /// Replaces whatever is stored under [key].
  Future<void> write(String key, String value);

  /// Removes [key]. Not an error if it does not exist.
  Future<void> delete(String key);
}
