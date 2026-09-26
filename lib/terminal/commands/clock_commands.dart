import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/clock_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/calendar_text.dart';
import 'package:android_terminal_launcher/terminal/tools/clock_input.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

const _commonLengths = ['5m', '10m', '25m', '1h'];

/// `timer 10m`, `timer 1h30m "pasta"`: starts a timer in the phone's clock app.
/// With no length it opens the clock app's timers, which is where they are
/// listed and cancelled.
Command timerCommand(ClockService clock) => Command(
  name: 'timer',
  description: 'Start a timer',
  usage: 'timer <length> [label]',
  forms: ['timer <length> [label]', 'timer'],
  examples: ['timer 10m', 'timer 1h30m tea', 'timer 90s'],
  notes: [
    'length: 90s, 10m, 1h30m, 25',
    '  (a bare number is minutes)',
    'up to 24 hours',
    'rung by your clock app; with no',
    '  length it opens your timers',
  ],
  run: (context) => _timer(clock, context.args, context.now()),
  argSuggestions: _suggestLengths,
);

/// `alarm 07:30`, `alarm 7am gym`, `alarm 06:45 weekdays`: sets an alarm in the
/// phone's clock app. With no time it opens the clock app's alarms, which is
/// where they are listed, changed and cancelled.
Command alarmCommand(ClockService clock) => Command(
  name: 'alarm',
  description: 'Set an alarm',
  usage: 'alarm <time> [days] [label]',
  forms: ['alarm <time> [days] [label]', 'alarm'],
  examples: ['alarm 07:30', 'alarm 6:45 weekdays', 'alarm 7pm gym'],
  notes: [
    'time: 07:30, 7:30, 7am, 19:45',
    'days: mon tue .. sun, weekdays,',
    '  weekend, daily (else once)',
    'rung by your clock app; with no',
    '  time it opens your alarms',
  ],
  run: (context) => _alarm(clock, context.args, context.now()),
);

List<String> _suggestLengths(String partial, List<AppInfo> apps) {
  if (partial.contains(' ')) return const [];
  final typed = partial.toLowerCase();
  return [
    for (final length in _commonLengths)
      if (length.startsWith(typed)) length,
  ];
}

// --- timer -----------------------------------------------------------------

Future<CommandResult> _timer(
  ClockService clock,
  List<String> args,
  DateTime now,
) async {
  if (args.isEmpty) {
    return _opened(
      await clock.showTimers(),
      Messages.timersOpened,
      Messages.timerError,
    );
  }
  final first = parseDuration(args.first);
  if (first == null) {
    return CommandFailure([
      Messages.timerBad(args.first),
      ...Messages.timerHelp,
    ]);
  }
  // `1h 30m`: a smaller unit straight after a larger one is the rest of it.
  var length = first;
  var used = 1;
  var rank = _lastUnitRank(args.first);
  while (used < args.length && rank > 0) {
    final next = _lastUnitRank(args[used]);
    final more = parseDuration(args[used]);
    if (next == 0 || next >= rank || more == null) break;
    length += more;
    rank = next;
    used++;
  }
  if (length < const Duration(seconds: 1)) {
    return CommandFailure.single(Messages.timerTooShort);
  }
  if (length > maxTimer) return CommandFailure.single(Messages.timerTooLong);

  final label = args.skip(used).join(' ').trim();
  final result = await clock.setTimer(
    length,
    label: label.isEmpty ? null : label,
  );
  switch (result) {
    case ClockDone():
      final ends = now.add(length);
      return noticeOutput(
        Messages.timerSet(formatDuration(length)),
        details: [
          Messages.timerEnds(_when(now, ends)),
          if (label.isNotEmpty) Messages.clockLabel(label),
        ],
      );
    case ClockUnavailable(:final reason):
      return CommandFailure.single(Messages.timerError(reason));
  }
}

/// 3 for hours, 2 for minutes, 1 for seconds, of the unit that ends [text];
/// 0 for a bare number or anything that does not end in one.
int _lastUnitRank(String text) {
  final match = RegExp(
    r'\d\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)$',
  ).firstMatch(text.trim().toLowerCase());
  if (match == null) return 0;
  return switch (match[1]![0]) {
    'h' => 3,
    'm' => 2,
    _ => 1,
  };
}

/// `14:35`, or with the day when it is not today: `Sun 02:10`.
String _when(DateTime now, DateTime at) {
  final time = clockText(at.hour, at.minute);
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return sameDay ? time : '${shortWeekday(at)} $time';
}

// --- alarm -----------------------------------------------------------------

Future<CommandResult> _alarm(
  ClockService clock,
  List<String> args,
  DateTime now,
) async {
  if (args.isEmpty) {
    return _opened(
      await clock.showAlarms(),
      Messages.alarmsOpened,
      Messages.alarmError,
    );
  }
  var used = 1;
  var time = parseClockTime(args.first);
  // `7:30 pm` written as two words.
  if (used < args.length) {
    final word = args[used].toLowerCase();
    if (word == 'am' || word == 'pm') {
      time = parseClockTime('${args.first}$word');
      used++;
    }
  }
  if (time == null) {
    return CommandFailure([
      Messages.alarmBad(args.first),
      ...Messages.alarmHelp,
    ]);
  }

  final days = <int>{};
  while (used < args.length) {
    final more = parseDays(args[used]);
    if (more == null) break;
    days.addAll(more);
    used++;
  }
  final label = args.skip(used).join(' ').trim();
  final weekdays = days.toList()..sort();

  final result = await clock.setAlarm(
    hour: time.hour,
    minute: time.minute,
    label: label.isEmpty ? null : label,
    weekdays: weekdays,
  );
  switch (result) {
    case ClockDone():
      final text = clockText(time.hour, time.minute);
      final when = weekdays.isEmpty
          ? _dayWord(now, nextOccurrence(now, time))
          : describeDays(weekdays);
      return noticeOutput(
        Messages.alarmSet(text, when),
        details: [if (label.isNotEmpty) Messages.clockLabel(label)],
      );
    case ClockUnavailable(:final reason):
      return CommandFailure.single(Messages.alarmError(reason));
  }
}

/// `today` or `tomorrow`, for the day [at] falls on.
String _dayWord(DateTime now, DateTime at) =>
    at.day == now.day && at.month == now.month ? 'today' : 'tomorrow';

CommandResult _opened(
  ClockResult result,
  String message,
  String Function(String reason) error,
) => switch (result) {
  ClockDone() => noticeOutput(message, kind: NoticeKind.info),
  ClockUnavailable(:final reason) => CommandFailure.single(error(reason)),
};
