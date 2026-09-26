import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';

/// The command line that opens the help for [name].
String helpCommandFor(String name) => 'help $name';

/// [HelpGroup] for [group], with each command's description.
HelpGroup helpGroupOf(CommandGroup group) => HelpGroup(
  name: group.name,
  command: helpCommandFor(group.name),
  commands: [
    for (final command in group.commands)
      HelpCommand(
        name: command.name,
        aliases: command.aliases,
        description: command.description,
        command: helpCommandFor(command.name),
      ),
  ],
);

/// What `help` shows: the groups and the names in them.
HelpOverviewBlock helpOverviewBlock(List<CommandGroup> groups) =>
    HelpOverviewBlock(
      groups: [for (final group in groups) helpGroupOf(group)],
      hint: Messages.helpHint,
    );

/// What `help <group>` shows.
HelpGroupBlock helpGroupBlock(CommandGroup group) =>
    HelpGroupBlock(group: helpGroupOf(group));

/// What `help <command>` shows. [group] is the group the command is in.
HelpDetailBlock helpDetailBlock(Command command, {CommandGroup? group}) =>
    HelpDetailBlock(
      name: command.name,
      description: command.description,
      usage: command.usageForms,
      examples: command.examples,
      notes: joinWrappedNotes(command.notes),
      aliases: command.aliases,
      group: group == null ? null : helpGroupOf(group),
    );

/// Notes are written to fit a 36-column screen, with a line that carries on
/// from the one before starting with spaces (`date: today, tomorrow` then
/// `  or 2026-09-30`). Joined into paragraphs they can wrap to any width.
List<String> joinWrappedNotes(List<String> notes) {
  final paragraphs = <String>[];
  for (final note in notes) {
    final continues = paragraphs.isNotEmpty && note.startsWith(' ');
    if (continues) {
      paragraphs[paragraphs.length - 1] = '${paragraphs.last} ${note.trim()}';
    } else {
      paragraphs.add(note.trim());
    }
  }
  return paragraphs;
}
