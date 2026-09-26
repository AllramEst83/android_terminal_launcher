import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:android_terminal_launcher/terminal/tools/expression.dart';

/// Args are joined with spaces, so `calc 2 * 3` and `calc 2*3` both work.
final calcCommand = Command(
  name: 'calc',
  description: 'Calculate a maths expression',
  usage: 'calc <expression>',
  examples: ['calc 2*(3+4)^2', 'calc sqrt(16)+pi', 'calc 10 % 3'],
  notes: [
    'operators: + - * / % ^ ( )',
    'constants: pi e',
    'functions: sqrt abs sin cos tan',
    '  asin acos atan ln log exp',
    '  floor ceil round',
    'angles are in radians',
  ],
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
