import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/contacts_service.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/contact_matcher.dart';

/// Outcome of turning what was typed into exactly one phone number.
sealed class RecipientResolution {
  const RecipientResolution();
}

final class ResolvedRecipient extends RecipientResolution {
  const ResolvedRecipient({required this.who, required this.number});

  /// For printing: `Anna Andersson (070-123 45 67)`, or the number as typed.
  final String who;

  /// Dialable: digits and a leading `+`.
  final String number;
}

/// Nothing usable was typed, or it matched nobody or several: [failure] is what
/// to print. Never a guess: an ambiguous name is listed, not picked.
final class UnresolvedRecipient extends RecipientResolution {
  const UnresolvedRecipient(this.failure);

  final CommandFailure failure;
}

/// Shared by every command that acts on one phone number (`call`, `sms`), so
/// they all pick a person the same way. A typed number needs no phone book (and
/// no permission to read it). A name is matched with [matchContacts] and must
/// leave exactly one person with exactly one number, or one mobile among
/// several.
///
/// [numberHint] and [pickHint] are the command's own last lines: how to go on
/// with a number instead of a name, and how to pick one of several numbers.
///
/// [completion] turns a chosen recipient (a name, or a number) into the whole
/// command line that would go on with it. The rich view offers those as a
/// picker whose taps *fill the prompt* with that line rather than run it: what
/// this leads to rings someone or sends a text, so it is looked at first and
/// sent with Enter.
Future<RecipientResolution> resolveRecipient(
  ContactsService contacts,
  String query, {
  required String numberHint,
  required String pickHint,
  required String Function(String recipient) completion,
}) async {
  if (looksLikeNumber(query)) {
    return ResolvedRecipient(who: query, number: dialable(query));
  }

  final result = await contacts.all();
  final List<Contact> everyone;
  switch (result) {
    case ContactsRead(:final contacts):
      everyone = contacts;
    case ContactsDenied(:final permanent):
      return UnresolvedRecipient(
        CommandFailure([
          ...Messages.permissionFailure(
            Messages.contacts,
            permanent: permanent,
          ),
          numberHint,
        ]),
      );
    case ContactsUnavailable(:final reason):
      return UnresolvedRecipient(
        CommandFailure([Messages.contactError(reason), numberHint]),
      );
  }

  final matches = matchContacts(everyone, query);
  if (matches.isEmpty) {
    return UnresolvedRecipient(
      CommandFailure.single(Messages.noContact(query)),
    );
  }
  if (matches.length > 1) {
    return UnresolvedRecipient(
      CommandFailure(
        [
          Messages.ambiguousContact(query),
          for (final contact in matches) '  ${contact.name}',
        ],
        block: ChoiceBlock(
          title: Messages.ambiguousContact(query),
          groups: [
            ChoiceGroup(
              options: [
                for (final contact in matches)
                  ChoiceOption(
                    label: contact.name,
                    fill: true,
                    command: completion(contact.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  final contact = matches.single;
  final number = _chooseNumber(contact);
  if (number == null) {
    return UnresolvedRecipient(
      CommandFailure(
        [
          Messages.severalNumbers(contact.name),
          for (final option in contact.numbers)
            '  ${option.label.padRight(7)} ${option.number}',
          pickHint,
        ],
        block: ChoiceBlock(
          title: Messages.severalNumbers(contact.name),
          layout: ChoiceLayout.rows,
          groups: [
            ChoiceGroup(
              options: [
                for (final option in contact.numbers)
                  ChoiceOption(
                    label: option.number,
                    description: option.label,
                    fill: true,
                    command: completion(dialable(option.number)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  return ResolvedRecipient(
    who: '${contact.name} (${number.number})',
    number: dialable(number.number),
  );
}

/// The one number to use: the only one, or the only mobile among several.
/// Null when there is a real choice to make, so nobody is contacted by a guess.
PhoneNumber? _chooseNumber(Contact contact) {
  if (contact.numbers.length == 1) return contact.numbers.single;
  final mobiles = [
    for (final number in contact.numbers)
      if (number.label == 'mobile') number,
  ];
  return mobiles.length == 1 ? mobiles.single : null;
}
