import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
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

/// Every name as a chip under a count. A tap looks the person up
/// (`contact "<name>"`), which shows and does nothing else.
ChoiceBlock contactNames(List<Contact> contacts) => ChoiceBlock(
  title: Messages.contactCount(contacts.length),
  groups: [
    ChoiceGroup(
      options: [
        for (final contact in contacts)
          ChoiceOption(
            label: contact.name,
            command: 'contact ${quoteArg(contact.name)}',
          ),
      ],
    ),
  ],
);
