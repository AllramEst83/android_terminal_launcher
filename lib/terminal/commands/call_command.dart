import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/services/phone_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/resolve_recipient.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// `call <name>` or `call <number>`. Rings straight away when Android allows
/// it, otherwise opens the dialer with the number filled in.
Command callCommand(ContactsService contacts, PhoneService phone) => Command(
  name: 'call',
  description: 'Call a contact or number',
  usage: 'call <name or number>',
  forms: ['call <name>', 'call <number>'],
  examples: ['call anna', 'call anna andersson', 'call 0701234567'],
  notes: [
    'a name is looked up in contacts',
    'several numbers: pick by number',
    'without call permission, the',
    'dialer opens instead',
  ],
  run: (context) => _call(contacts, phone, context.args.join(' ').trim()),
);

Future<CommandResult> _call(
  ContactsService contacts,
  PhoneService phone,
  String query,
) async {
  if (query.isEmpty) return const CommandFailure(Messages.callUsage);

  final recipient = await resolveRecipient(
    contacts,
    query,
    numberHint: Messages.callOrNumber,
    pickHint: Messages.callTryNumber,
    completion: (recipient) => 'call ${quoteArg(recipient)}',
  );
  return switch (recipient) {
    UnresolvedRecipient(:final failure) => failure,
    ResolvedRecipient(:final who, :final number) => _dial(phone, number, who),
  };
}

Future<CommandResult> _dial(
  PhoneService phone,
  String number,
  String who,
) async {
  return switch (await phone.call(number)) {
    CallPlaced() => noticeOutput(Messages.calling(who)),
    DialerOpened() => noticeOutput(
      Messages.dialerOpened(who),
      kind: NoticeKind.info,
    ),
    CallFailed(:final reason) => CommandFailure.single(
      Messages.callError(reason),
    ),
  };
}
