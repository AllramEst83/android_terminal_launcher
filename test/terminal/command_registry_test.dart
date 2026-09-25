import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/test_command.dart';

void main() {
  test('looks a command up by name', () {
    final list = testCommand('list');
    final registry = CommandRegistry([list]);

    expect(registry.lookup('list'), same(list));
  });

  test('looks a command up by alias', () {
    final list = testCommand('list', aliases: ['ls']);
    final registry = CommandRegistry([list]);

    expect(registry.lookup('ls'), same(list));
  });

  test('lookup is case-insensitive', () {
    final list = testCommand('list', aliases: ['ls']);
    final registry = CommandRegistry([list]);

    expect(registry.lookup('LIST'), same(list));
    expect(registry.lookup('Ls'), same(list));
  });

  test('unknown names return null', () {
    expect(CommandRegistry().lookup('nope'), isNull);
  });

  test('registering a duplicate name throws', () {
    final registry = CommandRegistry([testCommand('list')]);

    expect(() => registry.register(testCommand('LIST')), throwsArgumentError);
  });

  test('a clashing alias throws and registers nothing', () {
    final registry = CommandRegistry([
      testCommand('list', aliases: ['ls']),
    ]);

    expect(
      () => registry.register(testCommand('open', aliases: ['o', 'ls'])),
      throwsArgumentError,
    );
    expect(registry.lookup('open'), isNull);
    expect(registry.lookup('o'), isNull);
  });

  test('commands are sorted by name', () {
    final registry = CommandRegistry([
      testCommand('open'),
      testCommand('clear'),
      testCommand('list'),
    ]);

    expect(registry.commands.map((c) => c.name), ['clear', 'list', 'open']);
  });
}
