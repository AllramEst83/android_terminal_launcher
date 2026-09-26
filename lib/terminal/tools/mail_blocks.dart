import 'package:android_terminal_launcher/services/mail_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/mail_text.dart';

/// [found] as a card: a row per message with who, when and what about, and a
/// mark on the unread ones.
MailBlock mailBlock(MailMessages found, DateTime now) => MailBlock(
  summary: mailSummary(found),
  rows: [
    for (final message in found.messages)
      MailRow(
        uid: message.uid,
        sender: message.from,
        subject: mailSubject(message),
        when: mailWhen(message.date, now),
        unread: message.unread,
        removeCommand: 'mail rm #${message.uid}',
      ),
  ],
);
