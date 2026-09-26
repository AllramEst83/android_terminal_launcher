import 'package:android_terminal_launcher/services/android_location_service.dart';
import 'package:android_terminal_launcher/services/location_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';

const _channel = MethodChannel(AndroidLocationService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late FakePermissionService permissions;
  late AndroidLocationService service;
  setUp(() {
    permissions = FakePermissionService();
    service = AndroidLocationService(
      permissions: permissions,
      channel: _channel,
      timeout: const Duration(milliseconds: 50),
    );
  });

  test('asks for location permission, then for the position', () async {
    final calls = <String>[];
    _mockChannel((call) async {
      calls.add(call.method);
      return {'latitude': 57.7, 'longitude': 11.97};
    });

    final result = await service.current();

    expect(permissions.requested, [AppPermission.location]);
    expect(calls, ['current']);
    expect(result, isA<LocationFound>());
    expect((result as LocationFound).latitude, 57.7);
    expect(result.longitude, 11.97);
  });

  test('carries the place names when the platform found them', () async {
    _mockChannel(
      (call) async => {
        'latitude': 57.7,
        'longitude': 11.97,
        'name': 'Gothenburg',
        'region': 'Västra Götaland County',
        'country': 'Sweden',
      },
    );

    final result = await service.current() as LocationFound;

    expect(result.name, 'Gothenburg');
    expect(result.region, 'Västra Götaland County');
    expect(result.country, 'Sweden');
  });

  test(
    'a position without names, or with blank ones, is still found',
    () async {
      _mockChannel(
        (call) async => {'latitude': 1, 'longitude': 2, 'name': ' '},
      );

      final result = await service.current() as LocationFound;

      expect(result.name, isNull);
      expect(result.region, isNull);
      expect(result.country, isNull);
    },
  );

  test('whole-number coordinates arrive as doubles', () async {
    _mockChannel((call) async => {'latitude': 58, 'longitude': 12});

    final result = await service.current() as LocationFound;

    expect(result.latitude, 58.0);
    expect(result.longitude, 12.0);
  });

  test('a refused permission never reaches the platform', () async {
    permissions.answer = PermissionStatus.denied;
    var asked = false;
    _mockChannel((call) async {
      asked = true;
      return null;
    });

    final result = await service.current();

    expect(result, isA<LocationDenied>());
    expect((result as LocationDenied).permanent, isFalse);
    expect(asked, isFalse);
  });

  test('a permanent refusal is passed on as permanent', () async {
    permissions.answer = PermissionStatus.permanentlyDenied;

    final result = await service.current();

    expect((result as LocationDenied).permanent, isTrue);
  });

  test('permission revoked between the two calls is a denial', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NO_PERMISSION'),
    );

    final result = await service.current();

    expect(result, isA<LocationDenied>());
  });

  test('location switched off says so', () async {
    _mockChannel((call) async => throw PlatformException(code: 'LOCATION_OFF'));

    final result = await service.current();

    expect((result as LocationUnavailable).reason, contains('switched off'));
  });

  test('any other platform error is "no fix"', () async {
    _mockChannel((call) async => throw PlatformException(code: 'UNAVAILABLE'));

    final result = await service.current();

    expect((result as LocationUnavailable).reason, 'no location fix');
  });

  test('a reply without coordinates is "no fix"', () async {
    _mockChannel((call) async => {'latitude': 'north'});

    expect(await service.current(), isA<LocationUnavailable>());
  });

  test('a reply that never comes gives up', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    expect(await service.current(), isA<LocationUnavailable>());
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(await service.current(), isA<LocationUnavailable>());
  });
}
