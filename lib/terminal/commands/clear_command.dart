import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

final clearCommand = Command(
  name: 'clear',
  description: 'Clear the screen',
  usage: 'clear',
  run: (context) async => const CommandClear(),
);
