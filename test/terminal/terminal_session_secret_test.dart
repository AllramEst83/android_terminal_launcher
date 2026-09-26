import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';

const _secret = 'hunter2-is-my-password';

/// A command that asks for a secret and answers with what it did with it.
class _Rig {
  _Rig() {
    session = TerminalSession(
      registry: CommandRegistry([
        Command(
          name: 'login',
          description: 'asks for a secret',
          usage: 'login',
          run: (context) async => CommandAskSecret('password?', (secret) async {
            received.add(secret);
            if (again && received.length == 1) {
              return CommandAskSecret('again?', (second) async {
                received.add(second);
                return const CommandOutput(['confirmed']);
              });
            }
            if (explode) throw StateError('server on fire');
            return CommandOutput([
              'logged in with ${secret.length} characters',
            ]);
          }),
        ),
        Command(
          name: 'echo',
          description: 'prints hi',
          usage: 'echo',
          run: (context) async => const CommandOutput(['hi']),
        ),
      ]),
      apps: FakeAppRepository(),
    );
    addTearDown(session.dispose);
  }

  late final TerminalSession session;
  final received = <String>[];
  bool again = false;
  bool explode = false;

  List<String> get texts => [for (final line in session.lines) line.text];
}

void main() {
  test('asking shows the question and hides the next line', () async {
    final rig = _Rig();

    await rig.session.submit('login');

    expect(rig.session.askingSecret, isTrue);
    expect(rig.texts.last, 'password?');
  });

  test('the answer reaches the command and never the log', () async {
    final rig = _Rig();
    await rig.session.submit('login');

    await rig.session.submitFromPrompt(_secret);

    expect(rig.received, [_secret]);
    expect(rig.session.askingSecret, isFalse);
    expect(rig.texts.join('\n'), isNot(contains('hunter2')));
    expect(rig.texts, contains('${Messages.prompt}${Messages.secretEcho}'));
    expect(rig.texts.last, 'logged in with ${_secret.length} characters');
  });

  test('the placeholder is the same length whatever was typed', () async {
    final rig = _Rig();
    await rig.session.submit('login');
    await rig.session.submitFromPrompt('a');
    await rig.session.submit('login');
    await rig.session.submitFromPrompt('a much longer password than that');

    final echoes = rig.session.lines.where(
      (l) => l.kind == LogKind.input && l.text.contains(Messages.secretEcho),
    );
    expect(echoes.map((l) => l.text).toSet(), hasLength(1));
  });

  test('an empty line cancels without running anything', () async {
    final rig = _Rig();
    await rig.session.submit('login');

    await rig.session.submitFromPrompt('');

    expect(rig.received, isEmpty);
    expect(rig.session.askingSecret, isFalse);
    expect(rig.texts.last, Messages.secretCancelled);
    expect(rig.session.lines.last.kind, LogKind.error);
  });

  test('a command taps run while asking abandon the question', () async {
    final rig = _Rig();
    await rig.session.submit('login');

    await rig.session.submit('echo');

    expect(rig.received, isEmpty, reason: 'a tapped command is not the secret');
    expect(rig.session.askingSecret, isFalse);
    expect(rig.texts.last, 'hi');
  });

  test('after an answer the prompt takes commands again', () async {
    final rig = _Rig();
    await rig.session.submit('login');
    await rig.session.submitFromPrompt(_secret);

    await rig.session.submitFromPrompt('echo');

    expect(rig.texts.last, 'hi');
    expect(rig.received, [
      _secret,
    ], reason: 'the command was not sent as a secret');
  });

  test('a command may ask again', () async {
    final rig = _Rig()..again = true;
    await rig.session.submit('login');

    await rig.session.submitFromPrompt('first');
    expect(rig.session.askingSecret, isTrue);
    expect(rig.texts.last, 'again?');

    await rig.session.submitFromPrompt('second');
    expect(rig.received, ['first', 'second']);
    expect(rig.session.askingSecret, isFalse);
    expect(rig.texts.last, 'confirmed');
  });

  test('a command that throws prints an error, without the secret', () async {
    final rig = _Rig()..explode = true;
    await rig.session.submit('login');

    await rig.session.submitFromPrompt(_secret);

    expect(rig.session.lines.last.kind, LogKind.error);
    expect(rig.texts.last, contains('server on fire'));
    expect(rig.texts.join('\n'), isNot(contains('hunter2')));
    expect(rig.session.askingSecret, isFalse);
  });

  test('nothing is suggested while a secret is typed', () async {
    final rig = _Rig();
    expect(await rig.session.suggest('lo'), isNotEmpty);
    await rig.session.submit('login');

    expect(await rig.session.suggest('lo'), isEmpty);
    expect(await rig.session.suggest(_secret), isEmpty);
  });

  test('listeners hear when the question opens and closes', () async {
    final rig = _Rig();
    final states = <bool>[];
    rig.session.addListener(() => states.add(rig.session.askingSecret));

    await rig.session.submit('login');
    await rig.session.submitFromPrompt(_secret);

    expect(states.first, isFalse, reason: 'the echo of the command');
    expect(states, contains(true));
    expect(states.last, isFalse);
  });
}
