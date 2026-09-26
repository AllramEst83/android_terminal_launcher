import 'package:android_terminal_launcher/services/location_service.dart';

/// Answers with whatever [result] is set to and counts how often it was asked.
class FakeLocationService implements LocationService {
  FakeLocationService([this.result = const LocationDenied(permanent: false)]);

  LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}
