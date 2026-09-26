import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/cal_command.dart';

/// The phone's calendar. Built in `main.dart` with the real service.
class CalendarProvider implements CommandProvider {
  CalendarProvider(this.calendar);

  final CalendarService calendar;

  /// Shares a help group with the phone provider: one group per provider
  /// would push `help`'s overview past a small screen.
  @override
  String get name => 'personal';

  @override
  List<Command> get commands => [calCommand(calendar)];
}
