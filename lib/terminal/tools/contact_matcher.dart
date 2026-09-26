import 'package:android_terminal_launcher/services/contacts_service.dart';

/// Every contact whose name matches [query], from the best tier that has any
/// hit: the whole name, the start of the name, the start of any word in it
/// (`andersson` finds `Anna Andersson`), then anywhere in it. Case-insensitive.
/// Several hits in one tier are returned together so the caller can list them
/// instead of guessing. An empty query matches nothing.
List<Contact> matchContacts(List<Contact> contacts, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final tiers = <bool Function(String name)>[
    (name) => name == needle,
    (name) => name.startsWith(needle),
    (name) => name.split(RegExp(r'\s+')).any((word) => word.startsWith(needle)),
    (name) => name.contains(needle),
  ];
  for (final matches in tiers) {
    final hits = [
      for (final contact in contacts)
        if (matches(contact.name.toLowerCase())) contact,
    ];
    if (hits.isNotEmpty) return hits;
  }
  return const [];
}

final _numberPattern = RegExp(r'^\+?[\d\s()\-]+$');

/// Whether what was typed is a phone number rather than a name: digits, spaces,
/// dashes and brackets, with at least three digits, and at most a leading `+`.
bool looksLikeNumber(String text) {
  final trimmed = text.trim();
  return _numberPattern.hasMatch(trimmed) &&
      RegExp(r'\d').allMatches(trimmed).length >= 3;
}

/// [number] as the dialer wants it: digits and a leading `+`, nothing else.
String dialable(String number) => number.replaceAll(RegExp(r'[^\d+]'), '');
