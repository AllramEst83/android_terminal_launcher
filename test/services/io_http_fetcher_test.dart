import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/services/io_http_fetcher.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real server on this machine, so the real `dart:io` client is exercised
/// without leaving it. The address never leaves the loopback interface.
late HttpServer _server;
final _requests = <HttpRequest>[];

Uri _url(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

void main() {
  setUp(() async {
    _requests.clear();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      _requests.add(request);
      final response = request.response;
      switch (request.uri.path) {
        case '/ok':
          response.write('hello');
        case '/utf8':
          response.headers.contentType = ContentType.text;
          response.add(utf8.encode('Göteborg – Väder ☀'));
        case '/bad-bytes':
          response.add([0x68, 0x69, 0xFF, 0xFE, 0x21]);
        case '/missing':
          response.statusCode = 404;
          response.write('nope');
        case '/broken':
          response.statusCode = 500;
        case '/big':
          response.add(List.filled(5000, 65));
        case '/slow-start':
          await Future<void>.delayed(const Duration(seconds: 3));
          response.write('late');
        case '/stalls':
          response.headers.chunkedTransferEncoding = true;
          response.write('first');
          await response.flush();
          await Future<void>.delayed(const Duration(seconds: 3));
          response.write('second');
        case '/redirect':
          await response.redirect(_url('/ok'));
          return;
      }
      await response.close().catchError((Object _) {});
    });
  });

  tearDown(() => _server.close(force: true));

  IoHttpFetcher fetcher({Duration? timeout, int? maxBytes}) => IoHttpFetcher(
    timeout: timeout ?? const Duration(seconds: 5),
    maxBytes: maxBytes ?? 1024 * 1024,
  );

  Matcher failsWith(Pattern message) => throwsA(
    isA<NetworkException>().having(
      (e) => e.message,
      'message',
      contains(message),
    ),
  );

  test('returns the body of a successful response', () async {
    expect(await fetcher().get(_url('/ok')), 'hello');
  });

  test('decodes UTF-8, including non-Latin characters', () async {
    expect(await fetcher().get(_url('/utf8')), 'Göteborg – Väder ☀');
  });

  test('malformed bytes become replacement characters, not an error', () async {
    final body = await fetcher().get(_url('/bad-bytes'));

    expect(body, startsWith('hi'));
    expect(body, endsWith('!'));
    expect(body, contains('�'));
  });

  test('follows a redirect', () async {
    expect(await fetcher().get(_url('/redirect')), 'hello');
  });

  test('sends the user agent it was given', () async {
    await IoHttpFetcher(userAgent: 'my-launcher').get(_url('/ok'));

    expect(_requests.single.headers.value('user-agent'), 'my-launcher');
  });

  test(
    'an error status is a NetworkException naming the host and status',
    () async {
      await expectLater(
        fetcher().get(_url('/missing')),
        failsWith('127.0.0.1'),
      );
      await expectLater(fetcher().get(_url('/missing')), failsWith('404'));
      await expectLater(fetcher().get(_url('/broken')), failsWith('500'));
    },
  );

  test(
    'an error status carries its code, and other failures carry none',
    () async {
      NetworkException? notFound;
      NetworkException? broken;
      NetworkException? tooBig;
      try {
        await fetcher().get(_url('/missing'));
      } on NetworkException catch (error) {
        notFound = error;
      }
      try {
        await fetcher().get(_url('/broken'));
      } on NetworkException catch (error) {
        broken = error;
      }
      try {
        await fetcher(maxBytes: 1000).get(_url('/big'));
      } on NetworkException catch (error) {
        tooBig = error;
      }

      expect(notFound?.statusCode, 404);
      expect(broken?.statusCode, 500);
      expect(tooBig?.statusCode, isNull);
    },
  );

  test('a body over the limit is refused', () async {
    await expectLater(
      fetcher(maxBytes: 1000).get(_url('/big')),
      failsWith('too large'),
    );
  });

  test('a body under the limit is fine', () async {
    expect(await fetcher(maxBytes: 5000).get(_url('/big')), hasLength(5000));
  });

  test('a server that never answers times out', () async {
    await expectLater(
      fetcher(timeout: const Duration(milliseconds: 300))
          .get(_url('/slow-start')),
      failsWith('did not answer in time'),
    );
  });

  test('a transfer that stalls part-way times out too', () async {
    await expectLater(
      fetcher(timeout: const Duration(milliseconds: 300)).get(_url('/stalls')),
      failsWith('did not answer in time'),
    );
  });

  test('a closed port reads as no connection', () async {
    final port = _server.port;
    await _server.close(force: true);

    await expectLater(
      fetcher().get(Uri.parse('http://127.0.0.1:$port/ok')),
      failsWith("can't reach 127.0.0.1"),
    );
  });

  test('an unknown host reads as no connection', () async {
    await expectLater(
      fetcher().get(Uri.parse('http://no-such-host.invalid/')),
      failsWith("can't reach no-such-host.invalid"),
    );
  });
}
