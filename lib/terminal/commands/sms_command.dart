import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/sms_service.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/resolve_recipient.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// The longest text sent, roughly seven ordinary messages. A guard against a
/// paste gone wrong, not a limit anyone should meet.
const smsMaxLength = 1000;

/// `sms <name|number> "text"`. Exactly two arguments, so a name or text of
/// several words must be quoted: there is no way to tell where an unquoted name
/// ends and the text begins, and a message cannot be recalled once sent.
Command smsCommand(ContactsService contacts, SmsService sms) => Command(
  name: 'sms',
  description: 'Send a text message',
  usage: 'sms <to> "text"',
  forms: ['sms <name> "text"', 'sms <number> "text"'],
  examples: ['sms anna "on my way"', 'sms "anna andersson" hi'],
  notes: ['quote a name or text of several', 'words', Messages.smsSendingNote],
  run: (context) => _sms(contacts, sms, context.args),
  // The text is private, and history is shown on screen.
  history: HistoryPolicy.none,
);

Future<CommandResult> _sms(
  ContactsService contacts,
  SmsService sms,
  List<String> args,
) async {
  if (args.length != 2) return const CommandFailure(Messages.smsUsage);
  final query = args[0].trim();
  final text = args[1];
  if (query.isEmpty || text.trim().isEmpty) {
    return const CommandFailure(Messages.smsUsage);
  }
  if (text.length > smsMaxLength) {
    return CommandFailure.single(Messages.smsTooLong(smsMaxLength));
  }

  final recipient = await resolveRecipient(
    contacts,
    query,
    numberHint: Messages.smsOrNumber,
    pickHint: Messages.smsTryNumber,
    completion: (recipient) => 'sms ${quoteArg(recipient)} ${quoteArg(text)}',
  );
  switch (recipient) {
    case UnresolvedRecipient(:final failure):
      return failure;
    case ResolvedRecipient(:final who, :final number):
      return switch (await sms.send(number, text)) {
        SmsSent() => noticeOutput(Messages.smsSent(who)),
        SmsDenied(:final permanent) => CommandFailure(
          Messages.permissionFailure(Messages.sms, permanent: permanent),
        ),
        SmsFailed(:final reason) => CommandFailure.single(
          Messages.smsError(reason),
        ),
      };
  }
}
