/// What a command hands back to the session. Commands return values and never
/// touch the log or the UI themselves.
sealed class CommandResult {
  const CommandResult();
}

final class CommandOutput extends CommandResult {
  const CommandOutput(this.lines, {this.columns});

  final List<String> lines;

  /// Set when the lines are laid out on a fixed grid this many characters
  /// wide (a teletext page, a calendar). The UI then shrinks the text to fit
  /// the screen instead of wrapping lines, which would wreck the layout.
  final int? columns;
}

final class CommandFailure extends CommandResult {
  const CommandFailure(this.lines);

  CommandFailure.single(String message) : lines = [message];

  final List<String> lines;
}

final class CommandClear extends CommandResult {
  const CommandClear();
}
