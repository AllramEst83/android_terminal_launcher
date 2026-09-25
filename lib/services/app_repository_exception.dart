/// The platform could not list apps. Launch failures are a `false` result
/// instead, since they are an expected outcome a command can print.
class AppRepositoryException implements Exception {
  const AppRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
