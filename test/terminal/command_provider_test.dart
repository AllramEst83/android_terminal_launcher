import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/commands.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/test_command.dart';

/// The service a feature provider owns; a fake stands in for real storage.
class _Counter {
  int value = 0;
}

/// Shows the pattern real features follow: the provider is built with its
/// service and its commands close over it.
class _CounterProvider implements CommandProvider {
  _CounterProvider(this.counter);

  final _Counter counter;

  @override
  String get name => 'counter';

  @override
  List<Command> get commands => [
    Command(
      name: 'count',
      description: 'Add one and show the total',
      usage: 'count',
      run: (context) async {
        counter.value++;
        return CommandOutput(['${counter.value}']);
      },
    ),
  ];
}

class _StaticProvider implements CommandProvider {
  const _StaticProvider(this.name, this.commands);

  @override
  final String name;

  @override
  final List<Command> commands;
}

void main() {
  test('fromProviders registers the commands of every provider', () {
    final registry = CommandRegistry.fromProviders([
      _StaticProvider('one', [testCommand('alpha')]),
      _StaticProvider('two', [
        testCommand('beta', aliases: ['b']),
      ]),
    ]);

    expect(registry.lookup('alpha'), isNotNull);
    expect(registry.lookup('b'), isNotNull);
    expect(registry.commands.map((c) => c.name), ['alpha', 'beta']);
  });

  test('a name clash across providers throws and names the later one', () {
    expect(
      () => CommandRegistry.fromProviders([
        _StaticProvider('one', [testCommand('list')]),
        _StaticProvider('two', [testCommand('LIST')]),
      ]),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(startsWith('two:'), contains('list')),
        ),
      ),
    );
  });

  test('a provider with no commands is fine', () {
    final registry = CommandRegistry.fromProviders([
      const _StaticProvider('empty', []),
    ]);

    expect(registry.commands, isEmpty);
  });

  test('a provider command reaches its own service via the session', () async {
    final counter = _Counter();
    final session = TerminalSession(
      registry: CommandRegistry.fromProviders([
        ...defaultProviders,
        _CounterProvider(counter),
      ]),
      apps: FakeAppRepository(),
    );
    addTearDown(session.dispose);

    await session.submit('count');
    await session.submit('count');

    expect(counter.value, 2);
    expect(session.lines.last.text, '2');
  });

  test('the built-in providers are distinct and register without clashes', () {
    expect(defaultProviders.map((p) => p.name).toSet(), hasLength(3));
    expect(
      () => CommandRegistry.fromProviders(defaultProviders),
      returnsNormally,
    );
    expect(
      defaultCommands.map((c) => c.name),
      containsAll([
        'help',
        'clear',
        'date',
        'list',
        'open',
        'refresh',
        'uninstall',
        'calc',
        'convert',
      ]),
    );
  });
}
