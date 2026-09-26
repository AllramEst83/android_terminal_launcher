import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/contact_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/contact_matcher.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

/// More than this many matches are summarised, so a one-letter search doesn't
/// scroll the phone book past the screen.
const contactListLimit = 8;

/// `contact <name>`: who matches, and their numbers. `contact list`: everyone.
Command contactCommand(ContactsService contacts) => Command(
  name: 'contact',
  aliases: ['contacts'],
  description: 'Look up a contact',
  usage: 'contact <name>',
  forms: ['contact <name>', 'contact list'],
  examples: ['contact anna', 'contact andersson', 'contact list'],
  notes: [
    'matches the whole name, its start,',
    'any word in it, or a part',
    'list shows every name by initial;',
    'look one up to see its numbers',
  ],
  run: (context) => _contact(contacts, context.args.join(' ').trim()),
  argSuggestions: (partial, apps) => [
    if (!partial.contains(' ') && 'list'.startsWith(partial.toLowerCase()))
      'list',
  ],
);

Future<CommandResult> _contact(ContactsService contacts, String query) async {
  if (query.isEmpty) return const CommandFailure(Messages.contactUsage);

  final result = await contacts.all();
  switch (result) {
    case ContactsDenied(:final permanent):
      return CommandFailure(
        Messages.permissionFailure(Messages.contacts, permanent: permanent),
      );
    case ContactsUnavailable(:final reason):
      return CommandFailure.single(Messages.contactError(reason));
    case ContactsRead(:final contacts):
      if (query.toLowerCase() == 'list') return _list(contacts);
      final matches = matchContacts(contacts, query);
      if (matches.isEmpty) {
        return CommandFailure.single(Messages.noContact(query));
      }
      final shown = matches.take(contactListLimit).toList();
      final more = matches.length - shown.length;
      return CommandOutput([
        for (final contact in shown) ...[
          contact.name,
          for (final number in contact.numbers)
            '  ${number.label.padRight(7)} ${number.number}',
        ],
        if (more > 0) Messages.contactsMore(more),
      ], block: contactsBlock(shown, more: more));
  }
}

/// Every name, one per line, under a count and grouped by initial (A to Z, then
/// Å, Ä, Ö). Names only: a phone book of a few
/// hundred would otherwise scroll for pages, and `contact <name>` gives the
/// numbers. `list` is a keyword, so a contact whose whole name is "list" can
/// only be found by a longer part of its name.
CommandResult _list(List<Contact> contacts) {
  if (contacts.isEmpty) {
    return noticeOutput(Messages.contactsEmpty, kind: NoticeKind.info);
  }
  return CommandOutput([
    Messages.contactCount(contacts.length),
    for (final group in contactGroups(contacts)) ...[
      group.initial,
      for (final contact in group.contacts) '  ${contact.name}',
    ],
  ], block: contactNames(contacts));
}
