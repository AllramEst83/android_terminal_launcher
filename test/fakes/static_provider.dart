import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';

/// A provider that just hands out the commands it was given.
class StaticProvider implements CommandProvider {
  const StaticProvider(this.name, this.commands);

  @override
  final String name;

  @override
  final List<Command> commands;
}
