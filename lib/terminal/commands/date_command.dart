import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

final dateCommand = Command(
  name: 'date',
  aliases: ['time'],
  description: 'Show the current date and time',
  usage: 'date',
  run: (context) async => CommandOutput([_format(context.now())]),
);

/// e.g. `Fri 2026-09-25 16:30:12`, in the device's local time.
String _format(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final day = _weekdays[t.weekday - 1];
  return '$day ${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      ' ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
