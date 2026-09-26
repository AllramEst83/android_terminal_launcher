import 'package:android_terminal_launcher/services/contacts_service.dart';

/// Serves [result] and counts how often it was asked.
class FakeContactsService implements ContactsService {
  FakeContactsService([this.result = const ContactsRead([])]);

  ContactsResult result;
  int calls = 0;

  @override
  Future<ContactsResult> all() async {
    calls++;
    return result;
  }
}

/// A contact with numbers written as `label:number`.
Contact contact(String name, List<String> numbers) => Contact(
  name: name,
  numbers: [
    for (final entry in numbers)
      PhoneNumber(entry.split(':').last, entry.split(':').first),
  ],
);
