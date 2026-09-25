import 'package:android_terminal_launcher/terminal/command.dart';

/// One capability (apps, notes, calendar, …): a named group of related commands
/// plus the service they share. The provider is built with its service
/// (constructor injection) and hands out commands that close over it, so
/// `CommandContext` never grows a field per feature and the session and
/// registry never learn what a feature needs.
///
/// A provider only supplies commands. Whether a feature stays inline or hands
/// off to another app is decided inside its commands, not here.
abstract interface class CommandProvider {
  /// Short lowercase label, e.g. `notes`. Used in errors, and free for `help`
  /// to group by later.
  String get name;

  /// Every command this provider contributes. Called once at registration.
  List<Command> get commands;
}
