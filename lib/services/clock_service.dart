sealed class ClockResult {
  const ClockResult();
}

/// The clock app took it (or opened): a timer or alarm was set, or its list is
/// on screen.
class ClockDone extends ClockResult {
  const ClockDone();
}

/// The clock app could not be reached; [reason] is short and printable.
class ClockUnavailable extends ClockResult {
  const ClockUnavailable(this.reason);

  final String reason;
}

/// Timers and alarms, set through the phone's own clock app. It is what rings,
/// vibrates and survives a reboot, so an alarm is as reliable as one set by
/// hand and appears in the app the user already knows; this only sets them
/// (and opens their lists), it does not read or cancel them.
abstract class ClockService {
  /// Starts a timer of [length] (one second to 24 hours), running at once.
  /// Never throws; every failure is a [ClockUnavailable].
  Future<ClockResult> setTimer(Duration length, {String? label});

  /// Sets an alarm for [hour]:[minute] (24-hour). With no [weekdays] it rings
  /// once, next time the clock reads that; otherwise on those days, as
  /// `DateTime.monday` (1) to `DateTime.sunday` (7). Never throws.
  Future<ClockResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    List<int> weekdays = const [],
  });

  /// Opens the clock app's list of timers.
  Future<ClockResult> showTimers();

  /// Opens the clock app's list of alarms.
  Future<ClockResult> showAlarms();
}
