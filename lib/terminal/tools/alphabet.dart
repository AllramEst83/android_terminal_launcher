// Alphabetical order as a Swedish phone book keeps it: A to Z, then Å, Ä, Ö,
// with an accented letter filed under its plain one (É with E, Ü with U). Æ
// and Ø, which Swedish sorts with Ä and Ö, are filed there.

const _folds = {
  'a': 'àáâãāăą',
  'c': 'çćč',
  'd': 'ðď',
  'e': 'èéêëēęě',
  'i': 'ìíîï',
  'l': 'ł',
  'n': 'ñń',
  'o': 'òóôõōő',
  'r': 'ř',
  's': 'šśß',
  't': 'ť',
  'u': 'ùúûüūůű',
  'y': 'ýÿ',
  'z': 'žźż',
  // After z, in the order of the Swedish alphabet.
  '{': 'å',
  '|': 'äæ',
  '}': 'öø',
};

final Map<String, String> _fold = {
  for (final entry in _folds.entries)
    for (final letter in entry.value.split('')) letter: entry.key,
};

const _sortedLast = '{|}';
const _swedish = {'{': 'Å', '|': 'Ä', '}': 'Ö'};

/// What to sort [text] by: lower case, accents folded, and Å Ä Ö placed after
/// Z. Compare two of these with `compareTo`.
String alphabeticalKey(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final letter = String.fromCharCode(rune);
    buffer.write(_fold[letter] ?? letter);
  }
  return buffer.toString();
}

/// The letter [text] is filed under: its first letter in upper case, `Å`, `Ä`
/// or `Ö` for those, the plain letter for an accented one, and `#` for a digit,
/// a symbol or nothing at all.
String initialOf(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '#';
  final first = String.fromCharCode(trimmed.runes.first);
  final key = alphabeticalKey(first);
  if (_sortedLast.contains(key)) return _swedish[key]!;
  final upper = key.toUpperCase();
  return RegExp(r'\p{L}', unicode: true).hasMatch(upper) ? upper : '#';
}

/// Orders two initials from [initialOf]: A to Z, Å, Ä, Ö, other alphabets, and
/// `#` last.
int compareInitials(String a, String b) {
  if (a == '#') return b == '#' ? 0 : 1;
  if (b == '#') return -1;
  return alphabeticalKey(a).compareTo(alphabeticalKey(b));
}

/// [items] ordered by [name], the way a phone book is, keeping the given order
/// for two that come out equal.
List<T> sortedAlphabetically<T>(Iterable<T> items, String Function(T) name) {
  final keyed = [
    for (final (index, item) in items.indexed)
      (key: alphabeticalKey(name(item)), index: index, item: item),
  ];
  keyed.sort((a, b) {
    final byKey = a.key.compareTo(b.key);
    return byKey != 0 ? byKey : a.index.compareTo(b.index);
  });
  return [for (final entry in keyed) entry.item];
}
