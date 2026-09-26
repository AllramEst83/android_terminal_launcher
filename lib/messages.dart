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

  /// Runtime permissions, for every feature that asks for one. [what] is the
  /// capability's short name (`location`, `calendar`).
  static String permissionDenied(String what) => '$what permission denied';
  static String permissionOff(String what) => '$what permission is off';
  static const permissionHowToGrant = [
    'turn it on in the app settings:',
    'Apps > this app > Permissions',
  ];

  /// [permissionDenied], or where to turn it on when Android won't ask again.
  static List<String> permissionFailure(
    String what, {
    required bool permanent,
  }) => permanent
      ? [permissionOff(what), ...permissionHowToGrant]
      : [permissionDenied(what)];

  static const weatherUsage = ['usage: weather [city]', 'try: help weather'];
  static const weatherNoHome = 'no home city yet (try: weather home <city>)';
  static String weatherNoPlace(String query) =>
      "no place found called '$query'";
  static String weatherHome(String label) => 'home: $label';
  static String weatherHomeSet(String label) => 'home set to $label';
  static const weatherHomeCleared = 'home cleared';
  static String weatherError(String reason) => 'weather: $reason';

  /// Shown when Android could not name the spot: the position itself, so the
  /// user can still see where the forecast is for.
  static String weatherHere(double latitude, double longitude) =>
      'Current location (${latitude.toStringAsFixed(2)}, '
      '${longitude.toStringAsFixed(2)})';
  static const weatherLocation = 'location';
  static const weatherTryCity = 'or use: weather <city>';
  static const weatherSaveHome = 'or save one: weather home <city>';
  static const weatherUsingHome = 'no location, showing home';
  static const weatherToday = 'Today';

  /// The credit line under a forecast (SMHI's data licence asks for one).
  static String weatherSource(
    String source,
    String? station, {
    String? problem,
  }) {
    final credit = station == null ? source : '$source, measured at $station';
    return problem == null ? credit : '$credit (SMHI failed: $problem)';
  }

  static String weatherNow(String words, String temp, String feels) =>
      '$words, $temp (feels $feels)';
  static String weatherWind(String speed, String point, int humidity) =>
      'wind $speed m/s $point · humidity $humidity%';

  static const calendar = 'calendar';
  static const calUsage = [
    'usage: cal [day|week|month] [date]',
    'try: help cal',
  ];
  static String calBadDate(String text) =>
      "'$text' is not a date (try 2026-09-30)";
  static String calBadMonth(String text) =>
      "'$text' is not a month (try 2026-09)";
  static String calError(String reason) => 'cal: $reason';

  static const contacts = 'contacts';
  static const callUsage = ['usage: call <name or number>', 'try: help call'];
  static const contactUsage = ['usage: contact <name>', 'try: help contact'];
  static String noContact(String query) => "no contact matching '$query'";
  static String ambiguousContact(String query) =>
      "several contacts match '$query':";
  static String severalNumbers(String name) => '$name has several numbers:';
  static const callTryNumber = 'call one of them: call <number>';
  static const callOrNumber = 'or dial a number: call <number>';
  static String calling(String who) => 'calling $who';
  static String dialerOpened(String who) => 'dialer opened for $who';
  static String callError(String reason) => 'call: $reason';
  static String contactError(String reason) => 'contact: $reason';
  static String contactCount(int count) =>
      count == 1 ? '1 contact' : '$count contacts';
  static const contactsEmpty = 'no contacts with a phone number';
  static String contactsMore(int count) => '…and $count more';

  static const sms = 'sms';
  static const smsUsage = [
    'usage: sms <name or number> "text"',
    'quote a name or text of several',
    'words. try: help sms',
  ];
  static String smsTooLong(int max) => 'text is too long (max $max characters)';
  static const smsOrNumber = 'or use a number: sms <number> "text"';
  static const smsTryNumber = 'send to one: sms <number> "text"';
  static String smsSent(String who) => 'sent to $who';
  static String smsError(String reason) => 'sms: $reason';
  static const smsSendingNote = 'sent at once; cannot be undone';

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

  static const fontUsage = 'usage: font [size]';
  static const fontHeader = 'sizes:';
  static String fontChanged(String name) => 'font: $name';
  static String fontNotSaved(String reason) =>
      "could not save the size, so it won't survive a restart: $reason";
  static String unknownFontSize(String name, List<String> available) =>
      "no size called '$name' (available: ${available.join(', ')})";

  static const uiUsage = 'usage: ui [rich|plain]';
  static const uiHeader = 'views:';
  static String uiChanged(String name) => 'ui: $name, for new output';
  static String uiNotSaved(String reason) =>
      "could not save the view, so it won't survive a restart: $reason";
  static String unknownView(String name, List<String> available) =>
      "no view called '$name' (available: ${available.join(', ')})";

  static String entryMatches(int count, String query) =>
      "$count matching '$query'";

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

  /// What the log shows in place of a secret typed at a hidden prompt: always
  /// the same length, so it does not give the password's away.
  static const timerHelp = ['try: timer 10m, timer 1h30m', 'or: help timer'];
  static String timerBad(String text) => "'$text' is not a length of time";
  static const timerTooShort = 'a timer needs at least a second';
  static const timerTooLong = 'a timer can be 24 hours at most';
  static String timerSet(String length) => 'timer set: $length';
  static String timerEnds(String when) => 'ends $when';
  static const timersOpened = 'opened your timers in the clock app';
  static String timerError(String reason) => 'timer: $reason';
  static const alarmHelp = ['try: alarm 07:30, alarm 7am', 'or: help alarm'];
  static String alarmBad(String text) => "'$text' is not a time of day";
  static String alarmSet(String time, String when) => 'alarm set: $time, $when';
  static const alarmsOpened = 'opened your alarms in the clock app';
  static String alarmError(String reason) => 'alarm: $reason';
  static String clockLabel(String label) => 'label: $label';

  static const historyUsage = ['usage: history [clear]', 'try: help history'];
  static const historyEmpty = 'no history yet';
  static const historyCleared = 'history cleared';
  static String historyCount(int count) =>
      count == 1 ? 'history: 1 command' : 'history: $count commands';
  static const historyFooter = 'tap one to fill the prompt';

  static const secretEcho = '••••••••';
  static const secretCancelled = 'cancelled';

  /// The text of the spinner line, for what reads the log without drawing it
  /// (the UI shows a turning bar in its place).
  static const working = '[|]';

  static const mailUsage = [
    'usage: mail',
    '       mail rm <number>',
    '       mail setup <email> [server]',
    '       mail forget',
    'try: help mail',
  ];
  static const mailNoList = 'no list to go by yet (run: mail)';
  static String mailNoSuchNumber(int number, int count) =>
      'no message $number in the last list (1-$count)';
  static String mailNotInList(int uid) =>
      'message #$uid is not in the last list';
  static String mailMoved(String subject, String folder) =>
      'moved to $folder: $subject';
  static const mailMovedTip = 'it is in Trash if you want it back';
  static const mailAlreadyMoved = 'already moved to Trash';
  static const mailGone = 'that message is no longer in the inbox';
  static const mailNotSetUp = 'no mail account yet';
  static const mailHowToSetUp = 'set one up: mail setup <email>';
  static String mailError(String reason) => 'mail: $reason';
  static String mailBadAddress(String text) =>
      "'$text' is not an email address";
  static String mailNoServer(String domain) =>
      "don't know the mail server for $domain";
  static const mailGiveServer = 'add it: mail setup <email> <server>';
  static String mailPasswordPrompt(String email) =>
      'app password for $email (hidden; Enter alone cancels):';
  static String mailSetUp(String email) => 'reading mail as $email';
  static const mailTry = 'try: mail';
  static const mailForgotten = 'mail account removed from this phone';
  static const mailNothingToForget = 'no mail account to remove';
  static const mailEmpty = 'the inbox is empty';
  static const mailNoSubject = '(no subject)';

  /// [total] arrives already written for reading (`1,234`).
  static String mailSummary(
    int shown,
    int total,
    String totalText,
    int unread,
  ) {
    final count = shown < total
        ? 'latest $shown of $totalText'
        : (total == 1 ? '1 message' : '$totalText messages');
    return unread > 0 ? '$count, $unread unread' : count;
  }
}
