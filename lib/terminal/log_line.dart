import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';

/// `banner` is the startup/`clear` greeting; the UI renders it as
/// `AsciiBanner` instead of plain text (see `ui/terminal_log.dart`).
enum LogKind { input, output, error, banner }

class LogLine {
  const LogLine({
    required this.id,
    required this.kind,
    required this.text,
    this.columns,
    this.runs,
    this.block,
  });

  /// Unique and increasing, so the UI has stable keys even after the session
  /// drops old lines from the front.
  final int id;
  final LogKind kind;
  final String text;

  /// See `CommandOutput.columns`: the width of the grid this line belongs to.
  final int? columns;

  /// See `CommandOutput.styles`: this line's colours, when it has any.
  final List<StyledRun>? runs;

  /// When set, this one line stands for a whole rich block and the UI draws
  /// the block; [text] is then its plain lines joined with newlines.
  final RichBlock? block;
}
