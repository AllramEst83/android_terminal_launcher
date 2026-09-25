import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:android_terminal_launcher/terminal/tools/expression.dart';
import 'package:android_terminal_launcher/terminal/tools/units.dart';

/// `convert 5 km mi`, or `convert 5 km to mi`. The value may be an expression
/// without spaces (`convert 2*3 km mi`). `convert units` lists what is known.
final convertCommand = Command(
  name: 'convert',
  description: 'Convert between units, e.g. convert 5 km mi',
  usage: 'convert <value> <from> <to>',
  run: _convert,
  argSuggestions: suggestUnits,
);

/// Digits shown for a converted value; more would only show rounding noise.
const _resultDigits = 8;

Future<CommandResult> _convert(CommandContext context) async {
  final args = _withoutConnector(context.args);
  if (args.length == 1 && args.first.toLowerCase() == 'units') {
    return CommandOutput(_unitLines());
  }
  if (args.length != 3) return const CommandFailure(Messages.convertUsage);

  final from = findUnit(args[1]);
  if (from == null) {
    return CommandFailure.single(
      Messages.convertError(Messages.unknownUnit(args[1])),
    );
  }
  final to = findUnit(args[2]);
  if (to == null) {
    return CommandFailure.single(
      Messages.convertError(Messages.unknownUnit(args[2])),
    );
  }
  if (from.kind != to.kind) {
    return CommandFailure.single(
      Messages.convertError(
        Messages.unitMismatch(args[1], '${from.kind}', args[2], '${to.kind}'),
      ),
    );
  }

  final double value;
  try {
    value = evaluateExpression(args[0]);
  } on ExpressionException catch (error) {
    return CommandFailure.single(Messages.convertError(error.message));
  }
  final result = convertUnits(value, from, to);
  if (!result.isFinite) {
    return CommandFailure.single(Messages.convertError(Messages.exprTooLarge));
  }
  return CommandOutput([
    '${formatNumber(value)} ${args[1]} = '
        '${formatNumber(result, significant: _resultDigits)} ${args[2]}',
  ]);
}

/// Drops a `to` or `in` between the two units: `convert 5 km to mi`. Only when
/// it is unambiguous, so `convert 5 in cm` still means inches.
List<String> _withoutConnector(List<String> args) {
  if (args.length == 4 && const {'to', 'in'}.contains(args[2].toLowerCase())) {
    return [args[0], args[1], args[3]];
  }
  return args;
}

List<String> _unitLines() {
  final width = UnitKind.values.map((k) => k.name.length).reduce(_max);
  return [
    for (final kind in UnitKind.values)
      '${kind.name.padRight(width)}  '
          '${allUnits.where((u) => u.kind == kind).map((u) => u.symbol).join(' ')}',
  ];
}

int _max(int a, int b) => a > b ? a : b;

/// After a value and a unit, offers units of the same kind for the word being
/// typed. Nothing before that: there is no useful guess for a number or a
/// first unit.
List<String> suggestUnits(String partialArgs, List<AppInfo> apps) {
  final words = partialArgs.split(' ');
  // words: value, from, then the word being typed (possibly empty).
  if (words.length < 3) return const [];
  final from = findUnit(words[1]);
  if (from == null) return const [];

  final typing = words.last.toLowerCase();
  final prefix = words.sublist(0, words.length - 1).join(' ');
  return [
    for (final unit in allUnits)
      if (unit.kind == from.kind &&
          unit != from &&
          unit.symbol.startsWith(typing))
        '$prefix ${unit.symbol}',
  ];
}
