import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/help_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/static_provider.dart';
import '../../fakes/test_command.dart';

final _providers = <CommandProvider>[
  StaticProvider('system', [helpCommand, testCommand('clear')]),
  StaticProvider('tools', [
    testCommand('calc', aliases: ['c'], description: 'Calculate'),
    testCommand('convert'),
  ]),
];

Future<CommandResult> _run(
  List<String> args, {
  List<CommandProvider>? providers,
}) {
  final registry = CommandRegistry.fromProviders(providers ?? _providers);
  return helpCommand.run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: registry.commands,
      groups: registry.groups,
    ),
  );
}

void main() {
  test('plain help is the overview, with its block', () async {
    final result = await _run([]) as CommandOutput;

    final block = result.block as HelpOverviewBlock;
    expect(block.groups.map((g) => g.name), ['system', 'tools']);
    expect(result.lines.first, Messages.helpHeader);
  });

  test('help <group> is that group, with its block', () async {
    final result = await _run(['tools']) as CommandOutput;

    final block = result.block as HelpGroupBlock;
    expect(block.group.name, 'tools');
    expect(block.group.commands.map((c) => c.name), ['calc', 'convert']);
  });

  test('help <command> is that command, with the group it is in', () async {
    final result = await _run(['calc']) as CommandOutput;

    final block = result.block as HelpDetailBlock;
    expect(block.name, 'calc');
    expect(block.group!.name, 'tools');
    expect(block.aliases, ['c']);
  });

  test('an alias finds the command too', () async {
    final result = await _run(['C']) as CommandOutput;

    expect((result.block as HelpDetailBlock).name, 'calc');
  });

  test('--plain gives the text only, wherever it is put', () async {
    for (final args in [
      ['--plain'],
      ['tools', '--plain'],
      ['--plain', 'calc'],
    ]) {
      final result = await _run(args) as CommandOutput;

      expect(result.block, isNull, reason: '$args');
      expect(result.lines, isNotEmpty, reason: '$args');
    }
  });

  test('the text is the same with and without the block', () async {
    for (final args in [
      <String>[],
      ['tools'],
      ['calc'],
    ]) {
      final rich = await _run(args) as CommandOutput;
      final plain = await _run([...args, '--plain']) as CommandOutput;

      expect(plain.lines, rich.lines, reason: '$args');
    }
  });

  test('a mistake is still a failure, with or without the flag', () async {
    for (final args in [
      ['nothing'],
      ['nothing', '--plain'],
      ['a', 'b'],
    ]) {
      expect(await _run(args), isA<CommandFailure>(), reason: '$args');
    }
  });

  test('help on its own command mentions the flag', () async {
    final result = await _run(['help']) as CommandOutput;

    expect(result.lines.join('\n'), contains('--plain'));
  });

  test(
    'without groups there is one group of everything, unnamed in detail',
    () async {
      final result = await helpCommand.run(
        CommandContext(
          args: const ['calc'],
          apps: FakeAppRepository(),
          commands: [testCommand('calc')],
        ),
      ) as CommandOutput;

      expect((result.block as HelpDetailBlock).group, isNull);
    },
  );

  test(
    'every name in the overview opens real help (the taps lead somewhere)',
    () async {
      final overview =
          (await _run([]) as CommandOutput).block as HelpOverviewBlock;

      for (final group in overview.groups) {
        final groupHelp = await _run(group.command.split(' ').skip(1).toList());
        expect(groupHelp, isA<CommandOutput>(), reason: group.command);
        for (final command in group.commands) {
          final help = await _run(command.command.split(' ').skip(1).toList());
          expect(help, isA<CommandOutput>(), reason: command.command);
          expect(
            ((help as CommandOutput).block as HelpDetailBlock).name,
            command.name,
          );
        }
      }
    },
  );
}
