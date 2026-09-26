/// A request could not be completed: no connection, a timeout, an error
/// status, or an answer that made no sense. [message] is worded for the user
/// and names the host, so a command can print it as it is.
class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}
