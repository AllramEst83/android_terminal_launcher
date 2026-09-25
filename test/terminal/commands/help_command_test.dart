import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/commands/help_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/test_command.dart';

Future<List<String>> _help(List<Command> commands) async {
  final result = await helpCommand.run(
    CommandContext(
      args: const [],
      apps: FakeAppRepository(),
      commands: commands,
    ),
  );
  return (result as CommandOutput).lines;
}

void main() {
  test('is generated from the registry, with usage and description', () async {
    final registry = CommandRegistry([
      testCommand('zap', description: 'Zap it', usage: 'zap <x>'),
      testCommand('go', description: 'Go now'),
    ]);

    final lines = await _help(registry.commands);

    expect(lines, [
      Messages.helpHeader,
      '  go       Go now',
      '  zap <x>  Zap it',
    ]);
  });

  test('mentions aliases', () async {
    final lines = await _help([
      testCommand('list', aliases: ['ls', 'dir']),
    ]);

    expect(lines.last, contains('(aliases: ls, dir)'));
  });

  test('every default command shows up with its usage', () async {
    final lines = (await _help(CommandRegistry(defaultCommands).commands))
        .join('\n');

    for (final command in defaultCommands) {
      expect(lines, contains(command.usage));
    }
  });
}
