import 'dart:async';

import 'package:android_terminal_launcher/services/location_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';

/// [LocationService] backed by the Kotlin `LocationChannelHandler`, after
/// asking [PermissionService] for `location`. The only file that knows about
/// the channel.
class AndroidLocationService implements LocationService {
  const AndroidLocationService({
    required this._permissions,
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 30),
  });

  static const channelName =
      'com.codedbykay.android_terminal_launcher/location';

  final PermissionService _permissions;
  final MethodChannel _channel;

  /// The Kotlin side gives up on its own (15 s for a fix, 5 s more to name the
  /// place); this only guards against a reply that never comes, so the command
  /// can't hang forever.
  final Duration timeout;

  @override
  Future<LocationResult> current() async {
    final status = await _permissions.request(AppPermission.location);
    if (status != PermissionStatus.granted) {
      return LocationDenied(
        permanent: status == PermissionStatus.permanentlyDenied,
      );
    }
    try {
      final raw = await _channel
          .invokeMapMethod<String, Object?>('current')
          .timeout(timeout);
      final latitude = raw?['latitude'];
      final longitude = raw?['longitude'];
      if (latitude is! num || longitude is! num) {
        return const LocationUnavailable('no location fix');
      }
      return LocationFound(
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        name: _text(raw?['name']),
        region: _text(raw?['region']),
        country: _text(raw?['country']),
      );
    } on PlatformException catch (error) {
      return switch (error.code) {
        'NO_PERMISSION' => const LocationDenied(permanent: false),
        'LOCATION_OFF' => const LocationUnavailable(
          'location is switched off in Android',
        ),
        _ => const LocationUnavailable('no location fix'),
      };
    } on MissingPluginException {
      return const LocationUnavailable('location is not supported here');
    } on TimeoutException {
      return const LocationUnavailable('no location fix');
    }
  }

  /// A non-empty string, or null: the place names are optional extras.
  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
