import 'package:android_terminal_launcher/services/clock_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/clock_commands.dart';

/// Timers and alarms, through the phone's clock app. Built in `main.dart` with
/// the real service.
class ClockProvider implements CommandProvider {
  ClockProvider(this.clock);

  final ClockService clock;

  /// Shares the tools group with `calc` and `convert`.
  @override
  String get name => 'tools';

  @override
  List<Command> get commands => [timerCommand(clock), alarmCommand(clock)];
}
