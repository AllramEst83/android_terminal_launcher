class PhoneNumber {
  const PhoneNumber(this.number, this.label);

  /// As saved in the phone book (`070-123 45 67`, `+46 70 123 45 67`).
  final String number;

  /// Lowercase and short: `mobile`, `home`, `work`, or a custom label.
  final String label;
}

/// One person with a phone number. Entries with the same name (the same person
/// synced from two accounts) are merged, so a name is never listed twice and
/// its numbers are never repeated.
class Contact {
  const Contact({required this.name, required this.numbers});

  final String name;
  final List<PhoneNumber> numbers;
}

sealed class ContactsResult {
  const ContactsResult();
}

/// Everyone in the phone book who has a number, by name.
class ContactsRead extends ContactsResult {
  const ContactsRead(this.contacts);

  final List<Contact> contacts;
}

/// The user said no. [permanent] means Android will no longer ask, so the
/// caller should say where the setting is instead of asking again.
class ContactsDenied extends ContactsResult {
  const ContactsDenied({required this.permanent});

  final bool permanent;
}

/// Permission is fine but the phone book could not be read; [reason] is short
/// and printable.
class ContactsUnavailable extends ContactsResult {
  const ContactsUnavailable(this.reason);

  final String reason;
}

/// The phone's contacts, read-only. Asks for permission itself the first time.
abstract class ContactsService {
  /// Never throws; every failure is a [ContactsDenied] or
  /// [ContactsUnavailable]. Matching a name is the caller's job: a phone book
  /// is small, and matching in Dart keeps accents and case right.
  Future<ContactsResult> all();
}
