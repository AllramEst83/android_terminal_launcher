/// User-facing strings, kept in one place so the terminal's wording stays
/// consistent and testable.
abstract final class Messages {
  static const appTitle = 'Terminal Launcher';
  static const prompt = r'$ ';
  static const welcome = "Terminal Launcher. Type 'help' for commands.";

  static const helpHeader = 'commands';
  static const helpHint = 'try: help <name>  (e.g. help open)';
  static const helpUsage = 'usage: help [command or group]';
  static String helpUnknown(String name) => "no help for '$name' (try: help)";
  static const helpUsageLabel = 'usage:';
  static const helpExamplesLabel = 'examples:';
  static const helpNotesLabel = 'notes:';
  static String helpAliases(List<String> aliases) =>
      'aliases: ${aliases.join(', ')}';
  static const noApps = 'no apps found';
  static const openUsage = 'usage: open <app>';
  static const uninstallUsage = 'usage: uninstall <app>';
  static const unterminatedQuote = 'unterminated quote';

  static const calcUsage = ['usage: calc <expression>', 'try: help calc'];
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

  /// First form on the `usage:` line, the rest aligned beneath it.
  static List<String> entryUsage(String command, List<String> forms) => [
    'usage: $command ${forms.first}',
    for (final form in forms.skip(1)) '       $command $form',
  ];
  static String entryStorageFailed(String command, String reason) =>
      '$command: $reason';
  static String noEntries(String plural, String command) =>
      'no $plural yet (try: $command add "text")';
  static String entryAdded(String noun, int id) => 'added $noun $id';
  static String entryUpdated(String noun, int id) => 'updated $noun $id';
  static String entryRemoved(String noun, int id, String text) =>
      'removed $noun $id: $text';
  static String entryMissing(String noun, int id) => 'no $noun with id $id';
  static String entryBadId(String text) => "'$text' is not an entry id";
  static String entryNoMatches(String plural, String query) =>
      "no $plural matching '$query'";
  static String todoMarked(int id, {required bool done}) =>
      done ? 'todo $id done' : 'todo $id reopened';
  static String todosCleared(int count) => count == 0
      ? 'no finished todos to clear'
      : 'cleared $count finished ${count == 1 ? 'todo' : 'todos'}';

  static const weatherUsage = ['usage: weather [city]', 'try: help weather'];
  static const weatherNoHome = 'no home city yet (try: weather home <city>)';
  static String weatherNoPlace(String query) =>
      "no place found called '$query'";
  static String weatherHome(String label) => 'home: $label';
  static String weatherHomeSet(String label) => 'home set to $label';
  static const weatherHomeCleared = 'home cleared';
  static String weatherError(String reason) => 'weather: $reason';
  static const weatherToday = 'Today';
  static String weatherNow(String words, String temp, String feels) =>
      '$words, $temp (feels $feels)';
  static String weatherWind(String speed, String point, int humidity) =>
      'wind $speed m/s $point · humidity $humidity%';

  static const textTvUsage = [
    'usage: texttv [page] [part]',
    'try: help texttv',
  ];
  static String textTvBadPage(String text, int first, int last) =>
      "'$text' is not a Text TV page ($first-$last)";
  static String textTvBadPart(String text) => "'$text' is not a part number";
  static String textTvNotBroadcast(int page) =>
      'page $page is not in broadcast';
  static String textTvNoSuchPart(int page, int part, int parts) =>
      'page $page has ${parts == 1 ? '1 part' : '$parts parts'}, not $part';
  static String textTvError(String reason) => 'texttv: $reason';

  static const themeUsage = 'usage: theme [name]';
  static const themeHeader = 'themes:';
  static String themeChanged(String name) => 'theme: $name';
  static String themeNotSaved(String reason) =>
      "could not save the theme, so it won't survive a restart: $reason";
  static String unknownTheme(String name, List<String> available) =>
      "no theme called '$name' (available: ${available.join(', ')})";

  static const convertUsage = [
    'usage: convert <value> <from> <to>',
    'try: help convert',
  ];
  static String unknownCurrency(String code) =>
      "unknown currency '$code' (see 'convert currencies')";
  static String rateNote(String day, {required bool stale}) =>
      stale ? 'saved rates from $day (offline)' : 'rates from $day (ECB)';
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
