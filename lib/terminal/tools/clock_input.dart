/// The longest a timer may be: Android's clock takes one to 86,400 seconds.
const maxTimer = Duration(hours: 24);

final _unit = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)',
);

/// A length of time as people write it: `90s`, `10m`, `2h`, `1h30m`, `1.5h`,
/// `10 min`, and a bare number, which is minutes (`25`). Null when it is
/// anything else. Not bounded: the caller checks it against [maxTimer], so it
/// can say which way it was out.
Duration? parseDuration(String text) {
  final input = text.trim().toLowerCase();
  if (input.isEmpty) return null;

  final bare = double.tryParse(input.replaceFirst(',', '.'));
  if (bare != null && RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(input)) {
    return _seconds(bare * 60);
  }

  // Every character must belong to a `<number><unit>` pair.
  var total = 0.0;
  var next = 0;
  for (final match in _unit.allMatches(input)) {
    if (input.substring(next, match.start).trim().isNotEmpty) return null;
    next = match.end;
    final number = double.parse(match[1]!.replaceFirst(',', '.'));
    total += switch (match[2]![0]) {
      'h' => number * 3600,
      'm' => number * 60,
      _ => number,
    };
  }
  if (next == 0 || input.substring(next).trim().isNotEmpty) return null;
  return _seconds(total);
}

Duration _seconds(double seconds) => Duration(seconds: seconds.round());

/// `10 min`, `1 h 30 min`, `45 s`, `2 h`: as short as it can be.
String formatDuration(Duration length) {
  final hours = length.inHours;
  final minutes = length.inMinutes % 60;
  final seconds = length.inSeconds % 60;
  return [
    if (hours > 0) '$hours h',
    if (minutes > 0) '$minutes min',
    if (seconds > 0) '$seconds s',
  ].join(' ');
}

/// A time of day as `(hour, minute)` on a 24-hour clock.
typedef ClockTime = ({int hour, int minute});

final _clockTime = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$');
final _compactTime = RegExp(r'^(\d{2})(\d{2})$');

/// `07:30`, `7:30`, `7.30`, `0730`, `19:45`, `7`, `7pm`, `7:30 pm`, `12am`.
/// Null when it is not a time of day.
ClockTime? parseClockTime(String text) {
  final input = text.trim().toLowerCase();
  final compact = _compactTime.firstMatch(input);
  final match = compact ?? _clockTime.firstMatch(input);
  if (match == null) return null;

  var hour = int.parse(match[1]!);
  final minute = match[2] == null ? 0 : int.parse(match[2]!);
  final meridiem = compact == null ? match[3] : null;
  if (minute > 59) return null;
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
  }
  if (hour > 23) return null;
  return (hour: hour, minute: minute);
}

/// The next time the clock reads [time] after [now]: today if that is still to
/// come, else tomorrow. Calendar days, so a daylight-saving change never lands
/// it an hour off.
DateTime nextOccurrence(DateTime now, ClockTime time) {
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}

/// `07:30`.
String clockText(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

const _dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Days of the week for a repeating alarm, `DateTime.monday` (1) to
/// `DateTime.sunday` (7): a word for one day (`mon`, `monday`), or `weekdays`,
/// `weekend`, `daily`. Null when [word] is none of those.
List<int>? parseDays(String word) {
  final text = word.trim().toLowerCase();
  switch (text) {
    case 'daily' || 'everyday' || 'every-day':
      return [1, 2, 3, 4, 5, 6, 7];
    case 'weekdays':
      return [1, 2, 3, 4, 5];
    case 'weekend' || 'weekends':
      return [6, 7];
  }
  if (text.length < 3) return null;
  final index = _dayNames.indexWhere(
    (name) => text.startsWith(name) && _fullNames[name]!.startsWith(text),
  );
  return index < 0 ? null : [index + 1];
}

const _fullNames = {
  'mon': 'monday',
  'tue': 'tuesday',
  'wed': 'wednesday',
  'thu': 'thursday',
  'fri': 'friday',
  'sat': 'saturday',
  'sun': 'sunday',
};

/// `Mon-Fri`, `Sat Sun`, `daily`: [days] (1 to 7) as short as it reads.
String describeDays(List<int> days) {
  final sorted = ({...days}.toList()..sort());
  if (sorted.length == 7) return 'daily';
  final names = [for (final day in sorted) _label(day)];
  final consecutive =
      sorted.length >= 3 &&
      [for (var i = 1; i < sorted.length; i++) sorted[i] - sorted[i - 1]]
          .every((step) => step == 1);
  return consecutive ? '${names.first}-${names.last}' : names.join(' ');
}

String _label(int day) {
  final name = _dayNames[day - 1];
  return name[0].toUpperCase() + name.substring(1);
}
