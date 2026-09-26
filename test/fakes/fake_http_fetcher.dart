import 'dart:async';

import 'package:android_terminal_launcher/services/http_fetcher.dart';

/// Answers requests from a list of routes, so no test touches the network.
/// A request nothing routes is an error: a test must say what it expects the
/// code to ask for.
class FakeHttpFetcher implements HttpFetcher {
  final List<_Route> _routes = [];

  /// Every URL requested, in call order.
  final List<Uri> requests = [];

  /// Answers any URL containing [part] with [response]: a `String` body, an
  /// exception to throw, or a function of the URL returning either.
  void route(String part, Object response) =>
      _routes.insert(0, _Route(part, response));

  @override
  Future<String> get(Uri url) async {
    requests.add(url);
    for (final route in _routes) {
      if (!url.toString().contains(route.part)) continue;
      var response = route.response;
      if (response is Function) response = response(url) as Object;
      if (response is String) return response;
      if (response is Exception) throw response;
      throw ArgumentError('cannot answer with $response');
    }
    throw StateError('unexpected request: $url');
  }
}

class _Route {
  const _Route(this.part, this.response);

  final String part;
  final Object response;
}
