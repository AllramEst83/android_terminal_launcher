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

  group('groups', () {
    test('commands registered directly land in an "other" group', () {
      final registry = CommandRegistry([testCommand('a'), testCommand('b')]);

      expect(registry.groups.map((g) => g.name), ['other']);
      expect(registry.groups.single.commands.map((c) => c.name), ['a', 'b']);
    });

    test('a group can be named when registering', () {
      final registry = CommandRegistry()
        ..register(testCommand('zap'), group: 'files')
        ..register(testCommand('cat'), group: 'files')
        ..register(testCommand('ping'), group: 'net');

      expect(registry.groups.map((g) => g.name), ['files', 'net']);
      expect(registry.groups.first.commands.map((c) => c.name), ['zap', 'cat']);
    });

    test('a rejected command does not create or fill a group', () {
      final registry = CommandRegistry()
        ..register(testCommand('list'), group: 'one');

      expect(
        () => registry.register(testCommand('list'), group: 'two'),
        throwsArgumentError,
      );
      expect(registry.groups.map((g) => g.name), ['one']);
    });

    test('groups cannot be changed from outside', () {
      final registry = CommandRegistry()
        ..register(testCommand('a'), group: 'g');

      expect(
        () => registry.groups.first.commands.add(testCommand('b')),
        throwsUnsupportedError,
      );
    });
  });
}
