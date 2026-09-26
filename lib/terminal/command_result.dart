import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';

/// What a command hands back to the session. Commands return values and never
/// touch the log or the UI themselves.
sealed class CommandResult {
  const CommandResult();
}

final class CommandOutput extends CommandResult {
  const CommandOutput(this.lines, {this.columns, this.styles, this.block});

  final List<String> lines;

  /// Set when the lines are laid out on a fixed grid this many characters
  /// wide (a teletext page, a calendar). The UI then shrinks the text to fit
  /// the screen instead of wrapping lines, which would wreck the layout.
  final int? columns;

  /// Colours for [lines], one list of runs per line whose text is that line
  /// (`plainText(styles[i]) == lines[i]`). Only meaningful together with
  /// [columns]: a coloured grid is drawn by the UI on its own screen. Null for
  /// ordinary output, and always safe to ignore.
  final List<List<StyledRun>>? styles;

  /// A richer form of the same output, drawn as widgets instead of [lines]
  /// when the view mode is `rich`. [lines] must always say the same thing in
  /// text: they are what `plain` mode, tests and copying use. Null for
  /// ordinary output.
  final RichBlock? block;
}

final class CommandFailure extends CommandResult {
  const CommandFailure(this.lines, {this.block});

  CommandFailure.single(String message) : lines = [message], block = null;

  final List<String> lines;

  /// A richer form of the same failure, for one that asks the user to pick
  /// (several apps match): drawn as widgets when the view mode is `rich`, with
  /// [lines] as the text form, exactly as for [CommandOutput.block].
  final RichBlock? block;
}

/// Asks for a secret (a password) as the next line the user types. The
/// session shows [prompt], hides the field, and passes what is typed to
/// [then] without ever putting it in the log; an empty line cancels instead.
/// [then] gives the result to show, and may ask again. [busy] shows the spinner
/// while [then] runs, for one that goes online.
final class CommandAskSecret extends CommandResult {
  const CommandAskSecret(this.prompt, this.then, {this.busy = false});

  final String prompt;
  final Future<CommandResult> Function(String secret) then;
  final bool busy;
}

final class CommandClear extends CommandResult {
  const CommandClear();
}
