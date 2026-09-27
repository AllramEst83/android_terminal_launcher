import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/whatsapp_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/resolve_recipient.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// Long enough for a real message, short enough to guard against a paste gone
/// wrong; WhatsApp itself allows much more.
const waMaxLength = 1000;

/// `wa <name|number> ["text"]`. Opens the chat in WhatsApp, empty or with the
/// text ready; there is no API to send it, so the user types or taps send
/// there. One argument opens it empty; two means text, and a name or text of
/// several words must then be quoted.
Command waCommand(ContactsService contacts, WhatsAppService whatsapp) =>
    Command(
      name: 'wa',
      description: 'Open a WhatsApp chat, text ready',
      usage: 'wa <to> ["text"]',
      forms: ['wa <name>', 'wa <number>', 'wa <name> "text"'],
      examples: ['wa anna', 'wa anna "on my way"'],
      notes: [
        'quote a name or text of several',
        'words',
        Messages.waSendingNote,
      ],
      run: (context) => _wa(contacts, whatsapp, context.args),
      // The text is private, and history is shown on screen.
      history: HistoryPolicy.none,
    );

Future<CommandResult> _wa(
  ContactsService contacts,
  WhatsAppService whatsapp,
  List<String> args,
) async {
  if (args.isEmpty || args.length > 2) {
    return const CommandFailure(Messages.waUsage);
  }
  final query = args[0].trim();
  final text = args.length == 2 ? args[1] : '';
  if (query.isEmpty) return const CommandFailure(Messages.waUsage);
  if (text.length > waMaxLength) {
    return CommandFailure.single(Messages.waTooLong(waMaxLength));
  }

  final recipient = await resolveRecipient(
    contacts,
    query,
    numberHint: Messages.waOrNumber,
    pickHint: Messages.waTryNumber,
    completion: (recipient) => text.isEmpty
        ? 'wa ${quoteArg(recipient)}'
        : 'wa ${quoteArg(recipient)} ${quoteArg(text)}',
  );
  switch (recipient) {
    case UnresolvedRecipient(:final failure):
      return failure;
    case ResolvedRecipient(:final who, :final number):
      return switch (await whatsapp.openChat(number, text)) {
        WhatsAppOpened() => noticeOutput(Messages.waOpened(who)),
        WhatsAppFailed(:final reason) => CommandFailure.single(
          Messages.waError(reason),
        ),
      };
  }
}
