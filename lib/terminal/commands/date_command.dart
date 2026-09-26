import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

final dateCommand = Command(
  name: 'date',
  aliases: ['time'],
  description: 'Show the current date and time',
  usage: 'date',
  run: (context) async {
    final now = context.now();
    return CommandOutput([
      _format(now),
    ], block: ResultBlock(expression: _day(now), value: _clock(now)));
  },
);

String _two(int n) => n.toString().padLeft(2, '0');

/// `Fri 2026-09-25`.
String _day(DateTime t) =>
    '${_weekdays[t.weekday - 1]} ${t.year.toString().padLeft(4, '0')}-'
    '${_two(t.month)}-${_two(t.day)}';

/// `16:30:12`.
String _clock(DateTime t) =>
    '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

/// e.g. `Fri 2026-09-25 16:30:12`, in the device's local time.
String _format(DateTime t) => '${_day(t)} ${_clock(t)}';
