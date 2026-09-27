import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/log_line.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';

/// A command that asks an ordinary question and answers with what it did.
class _Rig {
  _Rig() {
    session = TerminalSession(
      registry: CommandRegistry([
        Command(
          name: 'wizard',
          description: 'asks for a name',
          usage: 'wizard',
          run: (context) async => CommandAsk(
            'name?',
            suggestions: (partial) => [
              for (final option in _names)
                if (option.startsWith(partial)) option,
            ],
            (name) async {
              received.add(name);
              if (again && received.length == 1) {
                return const CommandAsk('again?', _second);
              }
              if (explode) throw StateError('server on fire');
              return CommandOutput(['hello $name']);
            },
          ),
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

const _names = ['Ada', 'Alan'];

Future<CommandResult> _second(String answer) async {
  return CommandOutput(['confirmed $answer']);
}

void main() {
  test('asking shows the question and keeps the field visible', () async {
    final rig = _Rig();

    await rig.session.submit('wizard');

    expect(rig.session.askingInput, isTrue);
    expect(rig.session.askingSecret, isFalse);
    expect(rig.texts.last, 'name?');
  });

  test('the real answer reaches the command and the log', () async {
    final rig = _Rig();
    await rig.session.submit('wizard');

    await rig.session.submitFromPrompt('Ada');

    expect(rig.received, ['Ada']);
    expect(rig.session.askingInput, isFalse);
    expect(rig.texts, contains('${Messages.prompt}Ada'));
    expect(rig.texts.last, 'hello Ada');
  });

  test(
    'empty is not special: it goes to the command like anything else',
    () async {
      final rig = _Rig();
      await rig.session.submit('wizard');

      await rig.session.submitFromPrompt('');

      expect(rig.received, ['']);
      expect(rig.session.askingInput, isFalse);
      expect(rig.texts.last, 'hello ');
    },
  );

  test('cancel abandons the form without running anything', () async {
    final rig = _Rig();
    await rig.session.submit('wizard');

    await rig.session.submitFromPrompt('cancel');

    expect(rig.received, isEmpty);
    expect(rig.session.askingInput, isFalse);
    expect(rig.texts.last, Messages.askCancelled);
    expect(rig.session.lines.last.kind, LogKind.error);
  });

  test('a command tapped while asking abandons the question', () async {
    final rig = _Rig();
    await rig.session.submit('wizard');

    await rig.session.submit('echo');

    expect(rig.received, isEmpty, reason: 'a tapped command is not the answer');
    expect(rig.session.askingInput, isFalse);
    expect(rig.texts.last, 'hi');
  });

  test('a command may ask again, each step visible', () async {
    final rig = _Rig()..again = true;
    await rig.session.submit('wizard');

    await rig.session.submitFromPrompt('first');
    expect(rig.session.askingInput, isTrue);
    expect(rig.texts.last, 'again?');

    await rig.session.submitFromPrompt('second');
    expect(rig.received, ['first']);
    expect(rig.session.askingInput, isFalse);
    expect(rig.texts.last, 'confirmed second');
  });

  test('a command that throws prints an error', () async {
    final rig = _Rig()..explode = true;
    await rig.session.submit('wizard');

    await rig.session.submitFromPrompt('Ada');

    expect(rig.session.lines.last.kind, LogKind.error);
    expect(rig.texts.last, contains('server on fire'));
    expect(rig.session.askingInput, isFalse);
  });

  test('each step suggests its own completions, unlike a secret', () async {
    final rig = _Rig();
    await rig.session.submit('wizard');

    expect((await rig.session.suggest('A')).map((s) => s.completion), [
      'Ada',
      'Alan',
    ]);
  });

  test('listeners hear when the question opens and closes', () async {
    final rig = _Rig();
    final states = <bool>[];
    rig.session.addListener(() => states.add(rig.session.askingInput));

    await rig.session.submit('wizard');
    await rig.session.submitFromPrompt('Ada');

    expect(states.first, isFalse, reason: 'the echo of the command');
    expect(states, contains(true));
    expect(states.last, isFalse);
  });
}
