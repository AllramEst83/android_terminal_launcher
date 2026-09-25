/// Stored data could not be read or saved. A missing key is a `null` read
/// instead, since that is an expected outcome.
class LocalStoreException implements Exception {
  const LocalStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
