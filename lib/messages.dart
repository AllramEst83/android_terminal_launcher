/// User-facing strings, kept in one place so the terminal's wording stays
/// consistent and testable.
abstract final class Messages {
  static const appTitle = 'Terminal Launcher';
  static const prompt = r'$ ';
  static const welcome = "Terminal Launcher. Type 'help' for commands.";

  static const helpHeader = 'commands:';
  static const noApps = 'no apps found';
  static const openUsage = 'usage: open <app>';
  static const uninstallUsage = 'usage: uninstall <app>';
  static const unterminatedQuote = 'unterminated quote';

  static const calcUsage = [
    'usage: calc <expression>',
    '  operators: + - * / % ^ ( )   constants: pi e',
    '  functions: sqrt abs sin cos tan asin acos atan ln log exp',
    '             floor ceil round   (angles in radians)',
    '  example:   calc 2*(3+4)^2',
  ];
  static String calcError(String problem) => 'calc: $problem';
  static String exprUnexpected(String found) => "unexpected '$found'";
  static const exprUnexpectedEnd = 'expression ended unexpectedly';
  static const exprMissingParen = "missing ')'";
  static const exprDivideByZero = 'division by zero';
  static const exprNotReal = 'result is not a real number';
  static const exprTooLarge = 'result is too large';
  static const exprTooDeep = 'expression is nested too deeply';
  static String exprBadNumber(String text) => "bad number '$text'";
  static String exprUnknownName(String name) =>
      "unknown function or constant '$name'";

  static const convertUsage = [
    'usage: convert <value> <from> <to>',
    "  example: convert 5 km mi     (see all units: 'convert units')",
  ];
  static String convertError(String problem) => 'convert: $problem';
  static String unknownUnit(String name) =>
      "unknown unit '$name' (see 'convert units')";
  static String unitMismatch(
    String from,
    String fromKind,
    String to,
    String toKind,
  ) => 'cannot convert $from ($fromKind) to $to ($toKind)';

  static String uninstallStarted(String label) =>
      'asked Android to uninstall $label; confirm on screen, then run refresh';
  static String uninstallFailed(String label) =>
      'could not start uninstall for $label';
  static String refreshed(int count) =>
      'refreshed: $count ${count == 1 ? 'app' : 'apps'}';
  static String unknownCommand(String name) => 'unknown command: $name';
  static String noAppFound(String name) => 'no app found matching $name';
  static String ambiguousApp(String name) => "several apps match '$name':";
  static String opening(String label) => 'opening $label';
  static String launchFailed(String label) => 'could not launch $label';
  static String commandFailed(Object error) => 'error: $error';
}
