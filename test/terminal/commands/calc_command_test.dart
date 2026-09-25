import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/calc_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';

Future<CommandResult> _calc(List<String> args) {
  return calcCommand.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );
}

void main() {
  test('prints the result after an equals sign', () async {
    final result = await _calc(['2*(3+4)']) as CommandOutput;

    expect(result.lines, ['= 14']);
  });

  test('joins spaced-out args into one expression', () async {
    final result = await _calc(['2', '*', '3', '+', '1']) as CommandOutput;

    expect(result.lines, ['= 7']);
  });

  test('rounds float noise away', () async {
    final result = await _calc(['0.1+0.2']) as CommandOutput;

    expect(result.lines, ['= 0.3']);
  });

  test('a quoted expression works like an unquoted one', () async {
    final result = await _calc(['1 + 2']) as CommandOutput;

    expect(result.lines, ['= 3']);
  });

  test('no expression prints the usage and syntax help', () async {
    final result = await _calc([]) as CommandFailure;

    expect(result.lines, Messages.calcUsage);
  });

  test('a bad expression is a failure naming the problem', () async {
    final result = await _calc(['1/0']) as CommandFailure;

    expect(result.lines, [Messages.calcError(Messages.exprDivideByZero)]);
  });
}
