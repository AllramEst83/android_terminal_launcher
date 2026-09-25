import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';

/// Looks commands up by name or alias, case-insensitively.
class CommandRegistry {
  CommandRegistry([Iterable<Command> commands = const []]) {
    commands.forEach(register);
  }

  /// Registers every command of every provider. Throws [ArgumentError] if two
  /// providers (or one provider twice) claim the same name or alias; the message
  /// starts with the name of the provider that clashed.
  factory CommandRegistry.fromProviders(Iterable<CommandProvider> providers) {
    final registry = CommandRegistry();
    for (final provider in providers) {
      for (final command in provider.commands) {
        try {
          registry.register(command);
        } on ArgumentError catch (error) {
          throw ArgumentError('${provider.name}: ${error.message}');
        }
      }
    }
    return registry;
  }

  final Map<String, Command> _byKey = {};
  final List<Command> _commands = [];

  /// Throws [ArgumentError] if the name or any alias is already taken; nothing
  /// is registered in that case.
  void register(Command command) {
    final keys = [command.name, ...command.aliases].map((k) => k.toLowerCase());
    for (final key in keys) {
      if (_byKey.containsKey(key)) {
        throw ArgumentError('duplicate command name or alias: $key');
      }
    }
    for (final key in keys) {
      _byKey[key] = command;
    }
    _commands.add(command);
  }

  Command? lookup(String name) => _byKey[name.toLowerCase()];

  /// Sorted by name so `help` output is stable.
  List<Command> get commands => List.unmodifiable(
    [..._commands]..sort((a, b) => a.name.compareTo(b.name)),
  );
}
