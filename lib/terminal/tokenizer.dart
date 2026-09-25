import 'package:android_terminal_launcher/terminal/parsed_input.dart';

/// Splits an input line on whitespace. No quoting or chaining yet.
class Tokenizer {
  const Tokenizer();

  ParsedInput tokenize(String input) {
    final parts = input
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return const ParsedInput(command: '');
    return ParsedInput(command: parts.first, args: parts.sublist(1));
  }
}
