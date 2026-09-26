import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/services/currency_rates.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/number_format.dart';
import 'package:android_terminal_launcher/terminal/tools/expression.dart';
import 'package:android_terminal_launcher/terminal/tools/units.dart';

/// `convert 5 km mi`, or `convert 5 km to mi`, and money too: `convert 100 usd
/// sek`. The value may be an expression without spaces (`convert 2*3 km mi`).
/// `convert units` and `convert currencies` list what is known.
///
/// Units are converted offline. A pair that is not units but looks like two
/// currency codes goes to [rates], which needs the network only when it has no
/// recent saved copy.
Command convertCommand(CurrencyRates rates) => Command(
  name: 'convert',
  description: 'Convert units and currency',
  usage: 'convert <value> <from> <to>',
  forms: ['convert <value> <from> <to>', 'convert units', 'convert currencies'],
  examples: ['convert 5 km mi', 'convert 100 c f', 'convert 100 usd sek'],
  notes: [
    'to or in may sit between units',
    'money uses ECB rates, kept for',
    'offline use; the date is shown',
  ],
  run: (context) => _convert(rates, context.args),
  argSuggestions: suggestUnits,
);

/// Digits shown for a converted value; more would only show rounding noise.
const _resultDigits = 8;

Future<CommandResult> _convert(
  CurrencyRates rates,
  List<String> rawArgs,
) async {
  final args = _withoutConnector(rawArgs);
  if (args.length == 1) {
    switch (args.first.toLowerCase()) {
      case 'units':
        return CommandOutput(_unitLines());
      case 'currencies':
        return _currencies(rates);
    }
  }
  if (args.length != 3) return const CommandFailure(Messages.convertUsage);

  final from = findUnit(args[1]);
  final to = findUnit(args[2]);
  if (from == null && to == null) {
    if (_looksLikeCurrency(args[1]) && _looksLikeCurrency(args[2])) {
      return _money(rates, args);
    }
  }
  if (from == null) return _fail(Messages.unknownUnit(args[1]));
  if (to == null) return _fail(Messages.unknownUnit(args[2]));
  if (from.kind != to.kind) {
    return _fail(
      Messages.unitMismatch(args[1], '${from.kind}', args[2], '${to.kind}'),
    );
  }

  final double value;
  try {
    value = evaluateExpression(args[0]);
  } on ExpressionException catch (error) {
    return _fail(error.message);
  }
  final result = convertUnits(value, from, to);
  if (!result.isFinite) return _fail(Messages.exprTooLarge);
  return CommandOutput([
    '${formatNumber(value)} ${args[1]} = '
        '${formatNumber(result, significant: _resultDigits)} ${args[2]}',
  ]);
}

Future<CommandResult> _money(CurrencyRates rates, List<String> args) async {
  final double value;
  try {
    value = evaluateExpression(args[0]);
  } on ExpressionException catch (error) {
    return _fail(error.message);
  }
  final Rates current;
  try {
    current = await rates.rates();
  } on NetworkException catch (error) {
    return _fail(error.message);
  }
  for (final code in [args[1], args[2]]) {
    if (!current.knows(code)) return _fail(Messages.unknownCurrency(code));
  }
  final result = current.convert(value, args[1], args[2]);
  if (!result.isFinite) return _fail(Messages.exprTooLarge);
  return CommandOutput([
    '${formatNumber(value)} ${args[1].toUpperCase()} = '
        '${_amount(result)} ${args[2].toUpperCase()}',
    Messages.rateNote(current.day, stale: current.stale),
  ]);
}

Future<CommandResult> _currencies(CurrencyRates rates) async {
  final Rates current;
  try {
    current = await rates.rates();
  } on NetworkException catch (error) {
    return _fail(error.message);
  }
  return CommandOutput([
    ..._rows(current.codes),
    Messages.rateNote(current.day, stale: current.stale),
  ]);
}

/// Cents for everyday amounts, significant digits for tiny ones.
String _amount(double value) {
  if (value.abs() >= 0.01 || value == 0) return value.toStringAsFixed(2);
  return formatNumber(value, significant: 3);
}

bool _looksLikeCurrency(String text) => RegExp(r'^[A-Za-z]{3}$').hasMatch(text);

CommandFailure _fail(String problem) =>
    CommandFailure.single(Messages.convertError(problem));

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

/// Codes packed into rows that fit a phone screen.
List<String> _rows(List<String> words) {
  const width = 32;
  final rows = <String>[];
  var row = '';
  for (final word in words) {
    if (row.isEmpty) {
      row = word;
    } else if (row.length + 1 + word.length <= width) {
      row = '$row $word';
    } else {
      rows.add(row);
      row = word;
    }
  }
  if (row.isNotEmpty) rows.add(row);
  return rows;
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
