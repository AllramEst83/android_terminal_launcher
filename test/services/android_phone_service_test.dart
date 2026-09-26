import 'package:android_terminal_launcher/services/android_phone_service.dart';
import 'package:android_terminal_launcher/services/permission_service.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_permission_service.dart';

const _channel = MethodChannel(AndroidPhoneService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late FakePermissionService permissions;
  late AndroidPhoneService service;
  late List<MethodCall> calls;
  setUp(() {
    permissions = FakePermissionService();
    service = AndroidPhoneService(
      permissions: permissions,
      channel: _channel,
      timeout: const Duration(milliseconds: 50),
    );
    calls = [];
  });

  void answer(Object? Function(MethodCall call) reply) {
    _mockChannel((call) async {
      calls.add(call);
      return reply(call);
    });
  }

  test('with call permission it rings straight away', () async {
    answer((call) => true);

    final result = await service.call('0701234567');

    expect(result, isA<CallPlaced>());
    expect(permissions.requested, [AppPermission.phone]);
    expect(calls.map((c) => c.method), ['call']);
    expect(calls.single.arguments, {'number': '0701234567'});
  });

  test('without it, the dialer opens and nothing is called', () async {
    permissions.answer = PermissionStatus.denied;
    answer((call) => true);

    final result = await service.call('0701234567');

    expect(result, isA<DialerOpened>());
    expect(calls.map((c) => c.method), ['dial']);
  });

  test('a permanent refusal also just opens the dialer', () async {
    permissions.answer = PermissionStatus.permanentlyDenied;
    answer((call) => true);

    expect(await service.call('112'), isA<DialerOpened>());
  });

  test(
    'a number Android will not let an app ring falls back to the dialer',
    () async {
      answer((call) {
        if (call.method == 'call') {
          throw PlatformException(code: 'NO_PERMISSION');
        }
        return true;
      });

      final result = await service.call('112');

      expect(result, isA<DialerOpened>());
      expect(calls.map((c) => c.method), ['call', 'dial']);
    },
  );

  test('a call that says it did not start falls back to the dialer', () async {
    answer((call) => call.method == 'dial');

    expect(await service.call('0701234567'), isA<DialerOpened>());
  });

  test(
    'another error while calling is a failure, not a second attempt',
    () async {
      answer((call) => throw PlatformException(code: 'UNAVAILABLE'));

      final result = await service.call('0701234567');

      expect(result, isA<CallFailed>());
      expect(calls.map((c) => c.method), ['call']);
    },
  );

  test('a dialer that cannot open is a failure', () async {
    permissions.answer = PermissionStatus.denied;
    answer((call) => throw PlatformException(code: 'UNAVAILABLE'));

    expect(await service.call('0701234567'), isA<CallFailed>());
  });

  test('a reply that never comes is a failure', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    expect(await service.call('0701234567'), isA<CallFailed>());
  });

  test('no handler at all is unsupported, not a crash', () async {
    _mockChannel((call) => throw MissingPluginException());

    expect(await service.call('0701234567'), isA<CallFailed>());
  });
}
