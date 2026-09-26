import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:android_terminal_launcher/services/sms_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_provider.dart';
import 'package:android_terminal_launcher/terminal/commands/call_command.dart';
import 'package:android_terminal_launcher/terminal/commands/contact_command.dart';
import 'package:android_terminal_launcher/terminal/commands/sms_command.dart';

/// The phone book, calls and text messages. Built in `main.dart` with the real services.
class PhoneProvider implements CommandProvider {
  PhoneProvider({
    required this.contacts,
    required this.phone,
    required this.sms,
  });

  final ContactsService contacts;
  final PhoneService phone;
  final SmsService sms;

  /// Same help group as the calendar; see `CalendarProvider.name`.
  @override
  String get name => 'personal';

  @override
  List<Command> get commands => [
    contactCommand(contacts),
    callCommand(contacts, phone),
    smsCommand(contacts, sms),
  ];
}
