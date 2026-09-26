/// The only way features reach the network. Read-only: every service here asks
/// a public API a question and never sends anything about the user.
abstract interface class HttpFetcher {
  /// The body of `GET [url]` as text. Throws `NetworkException` when there is
  /// no connection, the server is too slow, it answers with a non-2xx status,
  /// or the body is unreasonably large.
  Future<String> get(Uri url);
}
