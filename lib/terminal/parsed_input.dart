/// One tokenized input line. A dedicated type so quoting, aliases and
/// chaining can grow inside the tokenizer without touching commands.
class ParsedInput {
  const ParsedInput({required this.command, this.args = const []});

  final String command;
  final List<String> args;

  bool get isEmpty => command.isEmpty;
}
