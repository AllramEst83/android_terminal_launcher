import 'package:android_terminal_launcher/services/clock_service.dart';

/// Records what it was asked and answers with [result].
class FakeClockService implements ClockService {
  ClockResult result = const ClockDone();

  /// `(length, label)` of every timer, in order.
  final List<(Duration, String?)> timers = [];

  /// Every alarm asked for, in order.
  final List<({int hour, int minute, String? label, List<int> weekdays})>
  alarms = [];

  int timersShown = 0;
  int alarmsShown = 0;

  @override
  Future<ClockResult> setTimer(Duration length, {String? label}) async {
    timers.add((length, label));
    return result;
  }

  @override
  Future<ClockResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    List<int> weekdays = const [],
  }) async {
    alarms.add((hour: hour, minute: minute, label: label, weekdays: weekdays));
    return result;
  }

  @override
  Future<ClockResult> showTimers() async {
    timersShown++;
    return result;
  }

  @override
  Future<ClockResult> showAlarms() async {
    alarmsShown++;
    return result;
  }
}
