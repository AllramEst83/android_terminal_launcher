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
          registry.register(command, group: provider.name);
        } on ArgumentError catch (error) {
          throw ArgumentError('${provider.name}: ${error.message}');
        }
      }
    }
    return registry;
  }

  final Map<String, Command> _byKey = {};
  final List<Command> _commands = [];
  final Map<String, List<Command>> _groups = {};

  /// Throws [ArgumentError] if the name or any alias is already taken; nothing
  /// is registered in that case.
  ///
  /// [group] is what `help` files the command under.
  void register(Command command, {String group = 'other'}) {
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
    _groups.putIfAbsent(group, () => []).add(command);
  }

  /// Commands by group, in the order they were registered.
  List<CommandGroup> get groups => [
    for (final entry in _groups.entries)
      CommandGroup(entry.key, List.unmodifiable(entry.value)),
  ];

  Command? lookup(String name) => _byKey[name.toLowerCase()];

  /// Sorted by name so `help` output is stable.
  List<Command> get commands => List.unmodifiable(
    [..._commands]..sort((a, b) => a.name.compareTo(b.name)),
  );
}
