import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/help_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

Command _command(
  String name, {
  List<String> aliases = const [],
  String description = 'does a thing',
  List<String> forms = const [],
  List<String> examples = const [],
  List<String> notes = const [],
}) => Command(
  name: name,
  aliases: aliases,
  description: description,
  usage: name,
  forms: forms,
  examples: examples,
  notes: notes,
  run: (context) async => const CommandOutput(['ok']),
);

void main() {
  test('help commands are typed as help and the name', () {
    expect(helpCommandFor('open'), 'help open');
  });

  group('helpGroupOf', () {
    final group = CommandGroup('tools', [
      _command('calc', description: 'Calculate'),
      _command('convert', aliases: ['conv'], description: 'Convert units'),
    ]);

    test('names the group and how to open its help', () {
      final help = helpGroupOf(group);

      expect(help.name, 'tools');
      expect(help.command, 'help tools');
    });

    test('lists every command with its aliases, description and command', () {
      final commands = helpGroupOf(group).commands;

      expect(commands.map((c) => c.name), ['calc', 'convert']);
      expect(commands.map((c) => c.aliases), [
        isEmpty,
        ['conv'],
      ]);
      expect(commands.map((c) => c.description), [
        'Calculate',
        'Convert units',
      ]);
      expect(commands.map((c) => c.command), ['help calc', 'help convert']);
    });

    test('a group with no commands is an empty list, not an error', () {
      expect(helpGroupOf(const CommandGroup('empty', [])).commands, isEmpty);
    });
  });

  test('the overview has every group in order, and the hint', () {
    final block = helpOverviewBlock([
      CommandGroup('a', [_command('one')]),
      CommandGroup('b', [_command('two'), _command('three')]),
    ]);

    expect(block.groups.map((g) => g.name), ['a', 'b']);
    expect(block.groups.last.commands.map((c) => c.name), ['two', 'three']);
    expect(block.hint, Messages.helpHint);
  });

  group('helpDetailBlock', () {
    final tools = CommandGroup('tools', [_command('calc')]);

    test('has the name, description, forms, examples, notes and aliases', () {
      final block = helpDetailBlock(
        _command(
          'calc',
          aliases: ['c'],
          description: 'Calculate',
          forms: ['calc <expression>', 'calc 2+2'],
          examples: ['calc 1+1'],
          notes: ['numbers only'],
        ),
        group: tools,
      );

      expect(block.name, 'calc');
      expect(block.description, 'Calculate');
      expect(block.usage, ['calc <expression>', 'calc 2+2']);
      expect(block.examples, ['calc 1+1']);
      expect(block.notes, ['numbers only']);
      expect(block.aliases, ['c']);
      expect(block.group!.command, 'help tools');
    });

    test('usage falls back to the one-line usage', () {
      expect(helpDetailBlock(_command('calc')).usage, ['calc']);
    });

    test('no group when none is given', () {
      expect(helpDetailBlock(_command('calc')).group, isNull);
    });
  });

  group('joinWrappedNotes', () {
    test('a line that carries on is joined to the one before', () {
      expect(
        joinWrappedNotes([
          'date: today, tomorrow, yesterday',
          '  or 2026-09-30',
          'month: this, next',
        ]),
        ['date: today, tomorrow, yesterday or 2026-09-30', 'month: this, next'],
      );
    });

    test('several continuations join in order', () {
      expect(joinWrappedNotes(['a', ' b', '  c']), ['a b c']);
    });

    test('notes that do not carry on stay apart', () {
      expect(joinWrappedNotes(['one', 'two']), ['one', 'two']);
    });

    test('a first note that starts with a space has nothing to join to', () {
      expect(joinWrappedNotes(['  odd', 'next']), ['odd', 'next']);
    });

    test('nothing gives nothing', () {
      expect(joinWrappedNotes(const []), isEmpty);
    });
  });
}
