import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:android_terminal_launcher/terminal/tools/expression.dart';

/// Args are joined with spaces, so `calc 2 * 3` and `calc 2*3` both work.
final calcCommand = Command(
  name: 'calc',
  description: 'Calculate an expression, e.g. calc 2*(3+4)',
  usage: 'calc <expression>',
  run: _calc,
);

Future<CommandResult> _calc(CommandContext context) async {
  final source = context.args.join(' ');
  if (source.isEmpty) return const CommandFailure(Messages.calcUsage);
  try {
    return CommandOutput(['= ${formatNumber(evaluateExpression(source))}']);
  } on ExpressionException catch (error) {
    return CommandFailure.single(Messages.calcError(error.message));
  }
}
