import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:android_terminal_launcher/services/http_fetcher.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';

/// [HttpFetcher] on `dart:io`, so it needs no package. This is the only file
/// that knows how requests are made.
class IoHttpFetcher implements HttpFetcher {
  IoHttpFetcher({
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 2 * 1024 * 1024,
    this.userAgent = 'android_terminal_launcher',
  });

  /// Applies to connecting, to the first byte of the answer, and to each chunk
  /// after that, so a stalled transfer ends too.
  final Duration timeout;

  /// Answers larger than this are refused rather than held in memory.
  final int maxBytes;
  final String userAgent;

  @override
  Future<String> get(Uri url) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = userAgent;
    try {
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>().timeout(timeout);
        throw NetworkException(
          '${url.host} answered with status ${response.statusCode}',
        );
      }
      final body = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        body.add(chunk);
        if (body.length > maxBytes) {
          throw NetworkException('the answer from ${url.host} is too large');
        }
      }
      // Bad bytes become replacement characters instead of failing the lot.
      return utf8.decode(body.takeBytes(), allowMalformed: true);
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      throw NetworkException('${url.host} did not answer in time');
    } on HandshakeException {
      throw NetworkException(
        'could not make a secure connection to ${url.host}',
      );
    } on SocketException {
      throw NetworkException("can't reach ${url.host} (no connection?)");
    } on HttpException catch (error) {
      throw NetworkException('${url.host}: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}
