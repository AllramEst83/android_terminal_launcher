import 'package:android_terminal_launcher/services/android_permission_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(AndroidPermissionService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  const service = AndroidPermissionService(_channel);

  test('asks for the named capability, not an Android string', () async {
    MethodCall? seen;
    _mockChannel((call) async {
      seen = call;
      return 'granted';
    });

    await service.request(AppPermission.location);

    expect(seen?.method, 'request');
    expect(seen?.arguments, {'permission': 'location'});
  });

  for (final MapEntry(key: answer, value: status) in const {
    'granted': PermissionStatus.granted,
    'denied': PermissionStatus.denied,
    'permanentlyDenied': PermissionStatus.permanentlyDenied,
  }.entries) {
    test("'$answer' becomes $status", () async {
      _mockChannel((call) async => answer);

      expect(await service.request(AppPermission.location), status);
    });
  }

  test('an answer it does not know is a denial', () async {
    _mockChannel((call) async => 'maybe');

    expect(
      await service.request(AppPermission.location),
      PermissionStatus.denied,
    );
  });

  test('a platform error is a denial, not a crash', () async {
    _mockChannel((call) async => throw PlatformException(code: 'BUSY'));

    expect(
      await service.request(AppPermission.location),
      PermissionStatus.denied,
    );
  });

  test('no handler at all is a denial too', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(
      await service.request(AppPermission.location),
      PermissionStatus.denied,
    );
  });
}
