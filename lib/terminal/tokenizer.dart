import 'package:android_terminal_launcher/terminal/parsed_input.dart';

/// Splits an input line into a command word and arguments. No chaining yet.
///
/// Whitespace separates words. A word that *starts* with `"` or `'` runs to the
/// matching quote, so it can hold spaces (`note add "buy milk"`) or be empty
/// (`""`). Inside `"…"` a backslash escapes `"` and `\`; `'…'` is literal.
/// Outside quotes a backslash escapes whitespace, a quote or a backslash
/// (`open my\ app`). A quote in the middle of a word is just a character, so
/// `open McDonald's` keeps working without quoting.
class Tokenizer {
  const Tokenizer();

  static final _whitespace = RegExp(r'\s');

  ParsedInput tokenize(String input) {
    final words = <String>[];
    final word = StringBuffer();
    var inWord = false;
    String? quote;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (quote != null) {
        if (char == quote) {
          quote = null;
        } else if (quote == '"' && char == r'\' && _escapable(input, i + 1)) {
          word.write(input[++i]);
        } else {
          word.write(char);
        }
        continue;
      }

      if (_whitespace.hasMatch(char)) {
        if (inWord) {
          words.add(word.toString());
          word.clear();
          inWord = false;
        }
        continue;
      }

      if (!inWord && (char == '"' || char == "'")) {
        quote = char;
      } else if (char == r'\' && _escapable(input, i + 1, whitespace: true)) {
        word.write(input[++i]);
      } else {
        word.write(char);
      }
      inWord = true;
    }

    if (quote != null) {
      return const ParsedInput(command: '', hasUnterminatedQuote: true);
    }
    if (inWord) words.add(word.toString());
    if (words.isEmpty) return const ParsedInput(command: '');
    return ParsedInput(command: words.first, args: words.sublist(1));
  }

  /// Whether the character at [index] may follow a backslash.
  bool _escapable(String input, int index, {bool whitespace = false}) {
    if (index >= input.length) return false;
    final char = input[index];
    return char == '"' ||
        char == "'" ||
        char == r'\' ||
        (whitespace && _whitespace.hasMatch(char));
  }
}
