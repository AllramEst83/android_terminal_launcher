import 'dart:async';

import 'package:android_terminal_launcher/services/http_fetcher.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/smhi.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers the forecast with a 404 at once and never answers the station list,
/// like a slow mobile connection meeting a place SMHI does not cover.
class _HangingStations implements HttpFetcher {
  final stationRequests = Completer<void>();

  @override
  Future<String> get(Uri url) {
    if (url.host.contains('metobs')) {
      if (!stationRequests.isCompleted) stationRequests.complete();
      return Completer<String>().future; // never
    }
    throw const NetworkException(
      'opendata-download-metfcst.smhi.se answered with status 404',
      statusCode: 404,
    );
  }
}

void main() {
  test(
    'out of area, the fallback does not wait for the station lookup',
    () async {
      final fetcher = _HangingStations();
      final smhi = Smhi(fetcher: fetcher);

      final result = smhi
          .forecast(
            const Place(name: 'New York', latitude: 40.7, longitude: -74),
          )
          .then<Object?>((_) => 'answered', onError: (Object e) => e)
          .timeout(const Duration(seconds: 2), onTimeout: () => 'waited');

      final outcome = await result;

      expect(outcome, isA<NetworkException>(), reason: '$outcome');
      expect((outcome as NetworkException).statusCode, 404);
      expect(
        fetcher.stationRequests.isCompleted,
        isTrue,
        reason: 'it did start',
      );
    },
  );
}
