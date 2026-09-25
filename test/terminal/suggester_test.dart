import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/suggester.dart';
import 'package:android_terminal_launcher/terminal/suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/test_command.dart';

const _firefox = AppInfo(label: 'Firefox', packageName: 'ff');
const _chrome = AppInfo(label: 'Chrome', packageName: 'chrome');
const _chromeBeta = AppInfo(label: 'Chrome Beta', packageName: 'chrome.beta');

final _commands = CommandRegistry(defaultCommands).commands;

List<Suggestion> _suggest(
  String input, {
  List<AppInfo> apps = const [_chrome, _chromeBeta, _firefox],
  Suggester suggester = const Suggester(),
}) {
  return suggester.suggest(input, commands: _commands, apps: apps);
}

List<String> _labels(List<Suggestion> s) => s.map((x) => x.label).toList();

void main() {
  group('command names', () {
    test('suggests commands by prefix', () {
      expect(_labels(_suggest('c')), ['calc', 'clear', 'convert']);
      expect(_labels(_suggest('re')), ['refresh']);
    });

    test('matching is case-insensitive', () {
      expect(_labels(_suggest('LI')), ['list']);
    });

    test('a command that takes arguments completes with a trailing space', () {
      expect(_suggest('op'), [
        const Suggestion(label: 'open', completion: 'open '),
      ]);
    });

    test('a command without arguments completes without one', () {
      expect(_suggest('cl'), [
        const Suggestion(label: 'clear', completion: 'clear'),
      ]);
    });

    test('aliases are suggested too', () {
      expect(_suggest('ti'), [
        const Suggestion(label: 'time', completion: 'time'),
      ]);
    });

    test('nothing is suggested for unknown words or empty input', () {
      expect(_suggest('zzz'), isEmpty);
      expect(_suggest(''), isEmpty);
      expect(_suggest('   '), isEmpty);
    });

    test('a fully typed command with no arguments is not repeated back', () {
      expect(_suggest('list'), isEmpty);
    });

    test('leading whitespace is ignored', () {
      expect(_labels(_suggest('  cl')), ['clear']);
    });
  });

  group('arguments', () {
    test('after `open ` every app is offered, in the given order', () {
      expect(_labels(_suggest('open ')), ['Chrome', 'Chrome Beta', 'Firefox']);
    });

    test('completions put the app after the command word as typed', () {
      expect(_suggest('open fire'), [
        const Suggestion(label: 'Firefox', completion: 'open Firefox'),
      ]);
    });

    test('exact, then prefix, then substring matches', () {
      const apps = [
        AppInfo(label: 'My Chrome', packageName: 'a'),
        AppInfo(label: 'Chrome Beta', packageName: 'b'),
        AppInfo(label: 'Chrome', packageName: 'c'),
      ];

      expect(_labels(_suggest('open chrome', apps: apps)), [
        'Chrome',
        'Chrome Beta',
        'My Chrome',
      ]);
    });

    test('apps with the same label are offered once', () {
      const apps = [
        AppInfo(label: 'Files', packageName: 'a'),
        AppInfo(label: 'Files', packageName: 'b'),
      ];

      expect(_labels(_suggest('open ', apps: apps)), ['Files']);
    });

    test('an app that is already fully typed is not repeated back', () {
      expect(_suggest('open Firefox'), isEmpty);
    });

    test('an app name suggestion still shows when only the case differs', () {
      expect(_labels(_suggest('open firefox')), ['Firefox']);
    });

    test('uninstall suggests apps like open does', () {
      expect(_suggest('uninstall fire'), [
        const Suggestion(label: 'Firefox', completion: 'uninstall Firefox'),
      ]);
    });

    test('nothing matches an unknown app', () {
      expect(_suggest('open zzz'), isEmpty);
    });

    test('works through a command alias', () {
      final commands = [
        testCommand('go', aliases: ['g'], argSuggestions: (p, a) => ['x', 'y']),
      ];

      final result = const Suggester().suggest(
        'g ',
        commands: commands,
        apps: const [],
      );

      expect(result.map((s) => s.completion), ['g x', 'g y']);
    });

    test('commands without argument suggestions offer nothing', () {
      expect(_suggest('list '), isEmpty);
      expect(_suggest('nope '), isEmpty);
    });
  });

  test('the list is capped', () {
    final apps = [
      for (var i = 0; i < 20; i++) AppInfo(label: 'App $i', packageName: '$i'),
    ];

    expect(_suggest('open ', apps: apps), hasLength(8));
    expect(
      _suggest(
        'open ',
        apps: apps,
        suggester: const Suggester(maxSuggestions: 3),
      ),
      hasLength(3),
    );
  });
}
