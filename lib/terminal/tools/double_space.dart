/// The result of [periodOnDoubleSpace]: the new text and where the cursor goes.
typedef DoubleSpaceEdit = ({String text, int cursor});

const _sentenceEnds = '.!?:,;';

/// The "double space makes a full stop" habit from phone keyboards, which the
/// prompt lacks because autocorrect is off (it would mangle commands).
///
/// Call it with the text before ([oldText]) and after ([newText]) a keystroke,
/// and the cursor after it. When that keystroke was a second space in a row it
/// returns the edit to make instead: the two spaces are dropped, the cursor
/// moves to the end of the text, and `. ` is put there, so `Test sentence`
/// followed by two spaces becomes `Test sentence. ` with the cursor after the
/// space. Otherwise it returns null and the keystroke stands.
///
/// It stays out of the way of commands. Nothing happens unless the text so far
/// is at least two words, so `list` followed by two stray spaces is left alone,
/// and a line that already ends in punctuation just gets one plain space
/// instead of `..`.
DoubleSpaceEdit? periodOnDoubleSpace(
  String oldText,
  String newText,
  int cursor,
) {
  // Exactly one space was typed, at the cursor, after another space.
  if (cursor < 2 || cursor > newText.length) return null;
  if (newText.length != oldText.length + 1) return null;
  if (newText[cursor - 1] != ' ' || newText[cursor - 2] != ' ') return null;
  final withoutTyped =
      newText.substring(0, cursor - 1) + newText.substring(cursor);
  if (withoutTyped != oldText) return null;

  // The two spaces come out; anything after the cursor stays. If that would
  // glue two words together (the double space was between them), one space
  // stays.
  final left = newText.substring(0, cursor - 2);
  final right = newText.substring(cursor);
  final glued =
      left.isNotEmpty &&
      right.isNotEmpty &&
      !left.endsWith(' ') &&
      !right.startsWith(' ');
  final body = (glued ? '$left $right' : left + right).trimRight();
  if (!body.trim().contains(RegExp(r'\s'))) return null;

  final endsSentence = _sentenceEnds.contains(body[body.length - 1]);
  final text = endsSentence ? '$body ' : '$body. ';
  return (text: text, cursor: text.length);
}
