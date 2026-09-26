import 'package:android_terminal_launcher/services/android_sms_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:android_terminal_launcher/services/sms_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';

const _channel = MethodChannel(AndroidSmsService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late FakePermissionService permissions;
  late AndroidSmsService service;
  setUp(() {
    permissions = FakePermissionService();
    service = AndroidSmsService(
      permissions: permissions,
      channel: _channel,
      timeout: const Duration(milliseconds: 50),
    );
  });

  test('asks for sms permission, then sends number and text', () async {
    MethodCall? seen;
    _mockChannel((call) async {
      seen = call;
      return true;
    });

    final result = await service.send('0701234567', 'hello');

    expect(result, isA<SmsSent>());
    expect(permissions.requested, [AppPermission.sms]);
    expect(seen?.method, 'send');
    expect(seen?.arguments, {'number': '0701234567', 'text': 'hello'});
  });

  test('a refused permission never reaches the platform', () async {
    permissions.answer = PermissionStatus.denied;
    var asked = false;
    _mockChannel((call) async {
      asked = true;
      return true;
    });

    final result = await service.send('0701234567', 'hi');

    expect((result as SmsDenied).permanent, isFalse);
    expect(asked, isFalse);
  });

  test('a permanent refusal is passed on as permanent', () async {
    permissions.answer = PermissionStatus.permanentlyDenied;

    expect(((await service.send('1', 'x')) as SmsDenied).permanent, isTrue);
  });

  test('permission revoked between the two calls is a denial', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NO_PERMISSION'),
    );

    expect(await service.send('0701234567', 'hi'), isA<SmsDenied>());
  });

  for (final MapEntry(key: code, value: reason) in const {
    'NO_SERVICE': 'no network service',
    'RADIO_OFF': 'flight mode is on',
    'SEND_FAILED': 'the message could not be sent',
    'UNAVAILABLE': 'the message could not be sent',
  }.entries) {
    test('$code is reported as "$reason"', () async {
      _mockChannel((call) async => throw PlatformException(code: code));

      final result = await service.send('0701234567', 'hi');

      expect((result as SmsFailed).reason, reason);
    });
  }

  test('an unconfirmed message warns against resending blindly', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NOT_CONFIRMED'),
    );

    final result = await service.send('0701234567', 'hi') as SmsFailed;

    expect(result.reason, contains('check before resending'));
  });

  test('a reply that never comes gives the same warning', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    final result = await service.send('0701234567', 'hi') as SmsFailed;

    expect(result.reason, contains('check before resending'));
  });

  test('a "false" answer is a failure, not a success', () async {
    _mockChannel((call) async => false);

    expect(await service.send('0701234567', 'hi'), isA<SmsFailed>());
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(await service.send('0701234567', 'hi'), isA<SmsFailed>());
  });
}
