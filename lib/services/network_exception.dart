/// A request could not be completed: no connection, a timeout, an error
/// status, or an answer that made no sense. [message] is worded for the user
/// and names the host, so a command can print it as it is.
class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});

  final String message;

  /// The HTTP status when the server answered with an error one (404, 503),
  /// so a caller can tell "nothing there" from "broken". Null otherwise.
  final int? statusCode;

  @override
  String toString() => message;
}
