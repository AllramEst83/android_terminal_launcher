import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/entry_store.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/services/weather.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/commands/help_command.dart';
import 'package:android_terminal_launcher/terminal/providers/appearance_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/info_provider.dart';
import 'package:android_terminal_launcher/terminal/providers/notes_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_font_size_settings.dart';
import '../../fakes/fake_http_fetcher.dart';
import '../../fakes/fake_theme_settings.dart';
import '../../fakes/in_memory_local_store.dart';
import '../../fakes/static_provider.dart';
import '../../fakes/test_command.dart';

/// Roughly how many characters fit on one line of a phone screen.
const _phoneColumns = 36;

Future<CommandResult> _run(CommandRegistry registry, List<String> args) {
  return helpCommand.run(
    CommandContext(
      args: args,
      apps: FakeAppRepository(),
      commands: registry.commands,
      groups: registry.groups,
    ),
  );
}

Future<List<String>> _help(
  Iterable<CommandProvider> providers, [
  List<String> args = const [],
]) async {
  final result = await _run(CommandRegistry.fromProviders(providers), args);
  return switch (result) {
    CommandOutput(:final lines) => lines,
    CommandFailure(:final lines) => lines,
    CommandClear() => fail('unexpected clear'),
  };
}

/// The same providers `main.dart` registers, with fakes behind them.
CommandRegistry _fullRegistry() {
  final store = InMemoryLocalStore();
  return CommandRegistry.fromProviders([
    ...defaultProviders,
    ToolsProvider(
      currency: CurrencyRates(fetcher: FakeHttpFetcher(), store: store),
    ),
    InfoProvider(
      textTv: TextTv(fetcher: FakeHttpFetcher()),
      weather: Weather(fetcher: FakeHttpFetcher(), store: store),
    ),
    AppearanceProvider(FakeThemeSettings(), FakeFontSizeSettings()),
    NotesProvider(
      notes: EntryStore(store: store, key: 'notes'),
      todos: EntryStore(store: store, key: 'todos'),
    ),
  ]);
}

void main() {
  group('overview', () {
    test(
      'lists each group with its command names, in provider order',
      () async {
        final lines = await _help([
          StaticProvider('files', [testCommand('zap'), testCommand('cat')]),
          StaticProvider('net', [testCommand('ping')]),
        ]);

        expect(lines, [
          Messages.helpHeader,
          '[files]',
          '  zap cat',
          '[net]',
          '  ping',
          Messages.helpHint,
        ]);
      },
    );

    test('packs names into rows that fit a phone', () async {
      final lines = await _help([
        StaticProvider('many', [
          for (var i = 0; i < 12; i++)
            testCommand('cmd${i.toString().padLeft(3, '0')}'),
        ]),
      ]);

      final rows = lines.where((l) => l.startsWith('  ')).toList();
      expect(rows.length, greaterThan(1));
      for (final row in rows) {
        expect(row.length, lessThanOrEqualTo(2 + 32), reason: row);
      }
      expect(
        rows.join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty),
        hasLength(12),
      );
    });

    test('a name too long for a row still gets its own row', () async {
      final long = 'x' * 40;

      final lines = await _help([
        StaticProvider('g', [
          testCommand('a'),
          testCommand(long),
          testCommand('b'),
        ]),
      ]);

      expect(lines, containsAllInOrder(['  a', '  $long', '  b']));
    });

    test('without groups everything is listed as one group', () async {
      final result = await helpCommand.run(
        CommandContext(
          args: const [],
          apps: FakeAppRepository(),
          commands: [testCommand('one'), testCommand('two')],
        ),
      );

      expect((result as CommandOutput).lines, [
        Messages.helpHeader,
        '[commands]',
        '  one two',
        Messages.helpHint,
      ]);
    });

    test(
      'the hint comes last, where it is seen first on a small screen',
      () async {
        final lines = await _help([
          StaticProvider('g', [testCommand('a')]),
        ]);

        expect(lines.last, Messages.helpHint);
      },
    );
  });

  group('help <group>', () {
    test('shows each command with its description underneath', () async {
      final lines = await _help(
        [
          StaticProvider('files', [
            testCommand('zap', description: 'Zap it'),
            testCommand('cat', description: 'Print it'),
          ]),
        ],
        ['files'],
      );

      expect(lines, [
        '[files]',
        '  zap',
        '    Zap it',
        '  cat',
        '    Print it',
      ]);
    });

    test('shows aliases beside the name', () async {
      final lines = await _help(
        [
          StaticProvider('g', [
            testCommand('list', aliases: ['ls', 'dir']),
          ]),
        ],
        ['g'],
      );

      expect(lines[1], '  list (ls, dir)');
    });

    test('is matched ignoring case', () async {
      final lines = await _help(
        [
          StaticProvider('Files', [testCommand('a')]),
        ],
        ['fILES'],
      );

      expect(lines.first, '[Files]');
    });
  });

  group('help <command>', () {
    Command full() => Command(
      name: 'note',
      aliases: const ['n'],
      description: 'Keep notes',
      usage: 'note <add|list>',
      forms: const ['note add <text>', 'note list'],
      examples: const ['note add "hi"'],
      notes: const ['quote text with spaces'],
      run: (context) async => const CommandOutput([]),
    );

    test('shows description, usage, examples, notes and aliases', () async {
      final lines = await _help(
        [
          StaticProvider('g', [full()]),
        ],
        ['note'],
      );

      expect(lines, [
        'note',
        '  Keep notes',
        Messages.helpUsageLabel,
        '  note add <text>',
        '  note list',
        Messages.helpExamplesLabel,
        '  note add "hi"',
        Messages.helpNotesLabel,
        '  quote text with spaces',
        'aliases: n',
      ]);
    });

    test(
      'usage falls back to the one-line usage, and empty sections are left out',
      () async {
        final lines = await _help(
          [
            StaticProvider('g', [
              testCommand('zap', description: 'Zap it', usage: 'zap <x>'),
            ]),
          ],
          ['zap'],
        );

        expect(lines, [
          'zap',
          '  Zap it',
          Messages.helpUsageLabel,
          '  zap <x>',
        ]);
      },
    );

    test('is found by alias, ignoring case', () async {
      final lines = await _help(
        [
          StaticProvider('g', [full()]),
        ],
        ['N'],
      );

      expect(lines.first, 'note');
    });

    test('wins over a group of the same name', () async {
      final lines = await _help(
        [
          StaticProvider('zap', [
            testCommand('zap', description: 'the command'),
          ]),
        ],
        ['zap'],
      );

      expect(lines, contains('  the command'));
      expect(lines.first, 'zap');
    });
  });

  group('errors', () {
    test('an unknown name is reported as typed', () async {
      final registry = CommandRegistry.fromProviders([
        StaticProvider('g', [testCommand('a')]),
      ]);

      final result = await _run(registry, ['Nope']);

      expect(result, isA<CommandFailure>());
      expect((result as CommandFailure).lines, [Messages.helpUnknown('Nope')]);
    });

    test('more than one argument prints the usage', () async {
      final registry = CommandRegistry.fromProviders([
        StaticProvider('g', [testCommand('a')]),
      ]);

      final result = await _run(registry, ['a', 'b']);

      expect(result, isA<CommandFailure>());
      expect((result as CommandFailure).lines, [Messages.helpUsage]);
    });
  });

  group('the real commands', () {
    test('every command is in the overview, under its own provider', () async {
      final registry = _fullRegistry();

      final lines = await _help(
        registry.groups.map((g) => StaticProvider(g.name, g.commands)),
      );

      for (final group in registry.groups) {
        expect(lines, contains('[${group.name}]'));
        for (final command in group.commands) {
          expect(
            lines.join('\n'),
            contains(command.name),
            reason: command.name,
          );
        }
      }
      expect(registry.groups.map((g) => g.name), [
        'system',
        'apps',
        'tools',
        'info',
        'appearance',
        'notes',
      ]);
    });

    test('every command has a description short enough for the group view', () {
      for (final command in _fullRegistry().commands) {
        // Indented four spaces in `help <group>`.
        expect(
          command.description.length,
          lessThanOrEqualTo(_phoneColumns - 4),
          reason: command.name,
        );
        expect(command.description, isNotEmpty);
      }
    });

    test('every form and example starts with the command name or an alias', () {
      for (final command in _fullRegistry().commands) {
        final starts = [command.name, ...command.aliases];
        for (final line in [...command.usageForms, ...command.examples]) {
          expect(
            starts.any((s) => line == s || line.startsWith('$s ')),
            isTrue,
            reason: '${command.name}: $line',
          );
        }
      }
    });

    test('no help line is wider than a phone screen', () async {
      final registry = _fullRegistry();
      final views = <String, List<String>>{
        'overview': await _help(
          registry.groups.map((g) => StaticProvider(g.name, g.commands)),
        ),
      };
      for (final group in registry.groups) {
        views['help ${group.name}'] = await _help(
          registry.groups.map((g) => StaticProvider(g.name, g.commands)),
          [group.name],
        );
      }
      for (final command in registry.commands) {
        views['help ${command.name}'] = await _help(
          registry.groups.map((g) => StaticProvider(g.name, g.commands)),
          [command.name],
        );
      }

      for (final entry in views.entries) {
        for (final line in entry.value) {
          expect(
            line.length,
            lessThanOrEqualTo(_phoneColumns),
            reason: '${entry.key}: "$line"',
          );
        }
      }
    });

    test('the overview fits on one small screen', () async {
      final registry = _fullRegistry();

      final lines = await _help(
        registry.groups.map((g) => StaticProvider(g.name, g.commands)),
      );

      expect(lines.length, lessThanOrEqualTo(16));
    });
  });
}
