import 'dart:async';

import 'package:android_terminal_launcher/services/clock_service.dart';
import 'package:flutter/services.dart';

/// [ClockService] backed by the Kotlin `ClockChannelHandler`, which asks the
/// phone's clock app through Android's `AlarmClock` intents. The only file that
/// knows about the channel.
class AndroidClockService implements ClockService {
  const AndroidClockService({
    this._channel = const MethodChannel(channelName),
    this.timeout = const Duration(seconds: 10),
  });

  static const channelName = 'com.codedbykay.android_terminal_launcher/clock';

  final MethodChannel _channel;

  /// Only guards against a reply that never comes.
  final Duration timeout;

  @override
  Future<ClockResult> setTimer(Duration length, {String? label}) =>
      _invoke('timer', {'seconds': length.inSeconds, 'label': label});

  @override
  Future<ClockResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    List<int> weekdays = const [],
  }) => _invoke('alarm', {
    'hour': hour,
    'minute': minute,
    'label': label,
    'days': weekdays,
  });

  @override
  Future<ClockResult> showTimers() => _invoke('showTimers', const {});

  @override
  Future<ClockResult> showAlarms() => _invoke('showAlarms', const {});

  Future<ClockResult> _invoke(String method, Map<String, Object?> args) async {
    try {
      final done = await _channel
          .invokeMethod<bool>(method, args)
          .timeout(timeout);
      return done == true
          ? const ClockDone()
          : const ClockUnavailable('the clock app did not answer');
    } on PlatformException catch (error) {
      return ClockUnavailable(switch (error.code) {
        'NO_PERMISSION' => 'not allowed to set alarms (check app permissions)',
        'NO_APP' => 'no clock app found',
        _ => error.message ?? 'could not reach the clock app',
      });
    } on MissingPluginException {
      return const ClockUnavailable('alarms are not supported here');
    } on TimeoutException {
      return const ClockUnavailable('the clock app did not answer');
    }
  }
}
