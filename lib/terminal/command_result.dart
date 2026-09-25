/// What a command hands back to the session. Commands return values and never
/// touch the log or the UI themselves.
sealed class CommandResult {
  const CommandResult();
}

final class CommandOutput extends CommandResult {
  const CommandOutput(this.lines);

  final List<String> lines;
}

final class CommandFailure extends CommandResult {
  const CommandFailure(this.lines);

  CommandFailure.single(String message) : lines = [message];

  final List<String> lines;
}

final class CommandClear extends CommandResult {
  const CommandClear();
}
