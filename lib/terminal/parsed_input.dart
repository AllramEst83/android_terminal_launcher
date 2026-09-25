/// One tokenized input line. A dedicated type so quoting, aliases and
/// chaining can grow inside the tokenizer without touching commands.
class ParsedInput {
  const ParsedInput({
    required this.command,
    this.args = const [],
    this.hasUnterminatedQuote = false,
  });

  final String command;
  final List<String> args;

  /// A quote was opened and never closed; [command] and [args] are then
  /// meaningless and the line must not run.
  final bool hasUnterminatedQuote;

  bool get isEmpty => command.isEmpty;
}
