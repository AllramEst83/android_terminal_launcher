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
