import 'package:android_terminal_launcher/services/android_clock_service.dart';
import 'package:android_terminal_launcher/services/clock_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel(AndroidClockService.channelName);

/// Stands in for the Kotlin side; the real platform is never touched in tests.
void _mockChannel(Future<Object?>? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => _mockChannel((call) => null));

  late AndroidClockService service;
  late List<MethodCall> calls;
  setUp(() {
    service = const AndroidClockService(
      channel: _channel,
      timeout: Duration(milliseconds: 50),
    );
    calls = [];
  });

  void answer(Object? Function(MethodCall call) reply) {
    _mockChannel((call) async {
      calls.add(call);
      return reply(call);
    });
  }

  test('a timer goes over as seconds and a label', () async {
    answer((call) => true);

    final result = await service.setTimer(
      const Duration(minutes: 10),
      label: 'pasta',
    );

    expect(result, isA<ClockDone>());
    expect(calls.single.method, 'timer');
    expect(calls.single.arguments, {'seconds': 600, 'label': 'pasta'});
  });

  test('a timer without a label sends none', () async {
    answer((call) => true);

    await service.setTimer(const Duration(seconds: 90));

    expect(calls.single.arguments, {'seconds': 90, 'label': null});
  });

  test('an alarm goes over as hour, minute, label and days', () async {
    answer((call) => true);

    final result = await service.setAlarm(
      hour: 6,
      minute: 45,
      label: 'gym',
      weekdays: [1, 2, 3],
    );

    expect(result, isA<ClockDone>());
    expect(calls.single.method, 'alarm');
    expect(calls.single.arguments, {
      'hour': 6,
      'minute': 45,
      'label': 'gym',
      'days': [1, 2, 3],
    });
  });

  test('an alarm with no days sends an empty list', () async {
    answer((call) => true);

    await service.setAlarm(hour: 7, minute: 0);

    expect((calls.single.arguments as Map)['days'], isEmpty);
  });

  test('the lists are opened by name', () async {
    answer((call) => true);

    await service.showTimers();
    await service.showAlarms();

    expect(calls.map((c) => c.method), ['showTimers', 'showAlarms']);
  });

  test('a reply that is not true is a clock app that did not answer', () async {
    answer((call) => false);

    final result = await service.showAlarms();

    expect(result, isA<ClockUnavailable>());
  });

  test('an empty reply is the same', () async {
    answer((call) => null);

    expect(
      await service.setTimer(const Duration(minutes: 1)),
      isA<ClockUnavailable>(),
    );
  });

  test('no clock app is said plainly', () async {
    _mockChannel((call) async => throw PlatformException(code: 'NO_APP'));

    final result = await service.setTimer(const Duration(minutes: 1));

    expect((result as ClockUnavailable).reason, 'no clock app found');
  });

  test('a refused permission says where to look', () async {
    _mockChannel(
      (call) async => throw PlatformException(code: 'NO_PERMISSION'),
    );

    final result = await service.setAlarm(hour: 7, minute: 0);

    expect((result as ClockUnavailable).reason, contains('permissions'));
  });

  test('any other platform error keeps its message', () async {
    _mockChannel(
      (call) async =>
          throw PlatformException(code: 'UNAVAILABLE', message: 'odd'),
    );

    expect((await service.showAlarms() as ClockUnavailable).reason, 'odd');
  });

  test('a platform error with no message still says something', () async {
    _mockChannel((call) async => throw PlatformException(code: 'UNAVAILABLE'));

    expect((await service.showAlarms() as ClockUnavailable).reason, isNotEmpty);
  });

  test('with no platform behind it, it says it is not supported', () async {
    _mockChannel((call) => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);

    final result = await service.showAlarms();

    expect((result as ClockUnavailable).reason, contains('not supported'));
  });

  test('a reply that never comes ends in a message, not a hang', () async {
    _mockChannel((call) => Future<Object?>.delayed(const Duration(seconds: 5)));

    final result = await service.setTimer(const Duration(minutes: 1));

    expect((result as ClockUnavailable).reason, contains('did not answer'));
  });
}
