import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/mail_command.dart';

/// Email. Built in `main.dart` with the real service.
class MailProvider implements CommandProvider {
  MailProvider(this.mail);

  final MailService mail;

  /// Same help group as the calendar and the phone book; see
  /// `CalendarProvider.name`.
  @override
  String get name => 'personal';

  @override
  List<Command> get commands => [mailCommand(mail)];
}
