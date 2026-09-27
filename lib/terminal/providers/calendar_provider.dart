import 'package:android_terminal_launcher/services/calendar_service.dart';
import 'package:android_terminal_launcher/services/local_store.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/cal_command.dart';
import 'package:android_terminal_launcher/terminal/commands/event_command.dart';
import 'package:android_terminal_launcher/terminal/tools/last_calendar_events.dart';

/// The phone's calendar. Built in `main.dart` with the real service. `cal` and
/// `event` share one [LastCalendarEvents], built here, so `event edit`/`event
/// rm` can name an event by its position in whatever `cal` last showed.
class CalendarProvider implements CommandProvider {
  CalendarProvider(this.calendar, {required this.store});

  final CalendarService calendar;
  final LocalStore store;
  final _lastEvents = LastCalendarEvents();

  /// Shares a help group with the phone provider: one group per provider
  /// would push `help`'s overview past a small screen.
  @override
  String get name => 'personal';

  @override
  List<Command> get commands => [
    calCommand(calendar, _lastEvents),
    eventCommand(calendar, _lastEvents, store),
  ];
}
