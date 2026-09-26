sealed class LocationResult {
  const LocationResult();
}

/// Roughly where the phone is (city-block accuracy: coarse location is enough
/// for a forecast).
class LocationFound extends LocationResult {
  const LocationFound({
    required this.latitude,
    required this.longitude,
    this.name,
    this.region,
    this.country,
  });

  final double latitude;
  final double longitude;

  /// Town or city, county/state and country, when Android could name the spot.
  /// It often can't (offline, or a phone without the geocoding service), so a
  /// caller must be able to show the position without them.
  final String? name;
  final String? region;
  final String? country;
}

/// The user said no. [permanent] means Android will no longer ask, so the
/// caller should say where the setting is rather than try again.
class LocationDenied extends LocationResult {
  const LocationDenied({required this.permanent});

  final bool permanent;
}

/// Permission is fine but there is no position: location is switched off in
/// Android, or no fix arrived in time. [reason] is short and printable.
class LocationUnavailable extends LocationResult {
  const LocationUnavailable(this.reason);

  final String reason;
}

/// Where the phone is right now. Asks for permission itself the first time, so
/// a command just calls [current] and reports what came back.
abstract class LocationService {
  /// Never throws; every failure is a [LocationDenied] or [LocationUnavailable].
  Future<LocationResult> current();
}
