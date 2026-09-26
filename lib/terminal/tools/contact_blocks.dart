import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/alphabet.dart';
import 'package:android_terminal_launcher/terminal/tools/contact_matcher.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// [contacts] as cards. Each number offers `call` and `sms`, which put the
/// command in the prompt (the number, digits only, so nothing in a name can
/// break the line) and never do it. [more] matched but are not shown.
ContactsBlock contactsBlock(List<Contact> contacts, {int more = 0}) =>
    ContactsBlock(
      more: more,
      contacts: [
        for (final contact in contacts)
          ContactCard(
            name: contact.name,
            numbers: [
              for (final number in contact.numbers)
                ContactNumber(
                  label: number.label,
                  number: number.number,
                  callCommand: 'call ${dialable(number.number)}',
                  smsCommand: 'sms ${dialable(number.number)} "',
                ),
            ],
          ),
      ],
    );

/// The contacts in phone-book order: A to Z, then Å, Ä, Ö, and `#` last for a
/// name that starts with a digit or a symbol. Grouped by initial, each group in
/// name order. What the plain list and the card both go by.
List<({String initial, List<Contact> contacts})> contactGroups(
  List<Contact> contacts,
) {
  final byInitial = <String, List<Contact>>{};
  for (final contact in sortedAlphabetically(contacts, (c) => c.name)) {
    byInitial.putIfAbsent(initialOf(contact.name), () => []).add(contact);
  }
  return [
    for (final initial in byInitial.keys.toList()..sort(compareInitials))
      (initial: initial, contacts: byInitial[initial]!),
  ];
}

/// Every name as a chip under its initial, and a count above. A tap looks the
/// person up (`contact "<name>"`), which shows and does nothing else.
ChoiceBlock contactNames(List<Contact> contacts) => ChoiceBlock(
  title: Messages.contactCount(contacts.length),
  groups: [
    for (final group in contactGroups(contacts))
      ChoiceGroup(
        title: group.initial,
        options: [
          for (final contact in group.contacts)
            ChoiceOption(
              label: contact.name,
              command: 'contact ${quoteArg(contact.name)}',
            ),
        ],
      ),
  ],
);
