/// [text] as one argument the tokenizer reads back as exactly [text]: left
/// alone when it is a plain word, otherwise in double quotes with `"` and `\`
/// escaped. For building the command lines a tap on a card runs or fills in.
String quoteArg(String text) {
  final plain = text.isNotEmpty && !RegExp(r'''[\s"'\\]''').hasMatch(text);
  if (plain) return text;
  final escaped = text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
