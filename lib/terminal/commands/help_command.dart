import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/plain_flag.dart';
import 'package:android_terminal_launcher/terminal/tools/help_blocks.dart';

/// Built from the registry, so it can never drift from what exists. Three
/// levels, each short enough for a phone screen (about 36 columns):
///
///  * `help` — every group with its command names packed onto a few rows;
///  * `help <group>` — each command in the group with its description;
///  * `help <command>` — usage, examples, notes and aliases for one command.
final helpCommand = Command(
  name: 'help',
  description: 'Show commands or help for one',
  usage: 'help [name]',
  forms: ['help', 'help <command>', 'help <group>'],
  examples: ['help open', 'help tools'],
  notes: ['--plain: text only, this once'],
  run: _help,
);

/// Names are packed into rows no wider than this, so a group of commands takes
/// a line or two on a phone instead of one line per command.
const _rowWidth = 32;

Future<CommandResult> _help(CommandContext context) async {
  final groups = _groupsOf(context);
  final (:args, :plain) = splitPlainFlag(context.args);
  if (args.isEmpty) {
    return CommandOutput(
      _overview(groups),
      block: plain ? null : helpOverviewBlock(groups),
    );
  }
  if (args.length > 1) return const CommandFailure([Messages.helpUsage]);

  final key = args.single.toLowerCase();
  final found = _findCommand(groups, key);
  if (found != null) {
    return CommandOutput(
      _detail(found.command),
      block: plain
          ? null
          : helpDetailBlock(
              found.command,
              // A lone catch-all group is not worth naming.
              group: context.groups.isEmpty ? null : found.group,
            ),
    );
  }
  for (final group in groups) {
    if (group.name.toLowerCase() == key) {
      return CommandOutput(
        _group(group),
        block: plain ? null : helpGroupBlock(group),
      );
    }
  }
  return CommandFailure.single(Messages.helpUnknown(args.single));
}

/// The context's groups, or everything as one group when none were given.
List<CommandGroup> _groupsOf(CommandContext context) {
  if (context.groups.isNotEmpty) return context.groups;
  return [CommandGroup('commands', context.commands)];
}

({Command command, CommandGroup group})? _findCommand(
  List<CommandGroup> groups,
  String key,
) {
  for (final group in groups) {
    for (final command in group.commands) {
      if ([
        command.name,
        ...command.aliases,
      ].any((k) => k.toLowerCase() == key)) {
        return (command: command, group: group);
      }
    }
  }
  return null;
}

List<String> _overview(List<CommandGroup> groups) => [
  Messages.helpHeader,
  for (final group in groups) ...[
    '[${group.name}]',
    for (final row in _pack([for (final c in group.commands) c.name])) '  $row',
  ],
  Messages.helpHint,
];

List<String> _group(CommandGroup group) => [
  '[${group.name}]',
  for (final command in group.commands) ...[
    command.aliases.isEmpty
        ? '  ${command.name}'
        : '  ${command.name} (${command.aliases.join(', ')})',
    '    ${command.description}',
  ],
];

List<String> _detail(Command command) => [
  command.name,
  '  ${command.description}',
  Messages.helpUsageLabel,
  for (final form in command.usageForms) '  $form',
  if (command.examples.isNotEmpty) ...[
    Messages.helpExamplesLabel,
    for (final example in command.examples) '  $example',
  ],
  if (command.notes.isNotEmpty) ...[
    Messages.helpNotesLabel,
    for (final note in command.notes) '  $note',
  ],
  if (command.aliases.isNotEmpty) Messages.helpAliases(command.aliases),
];

/// Greedy: as many words per row as fit in [_rowWidth].
List<String> _pack(List<String> words) {
  final rows = <String>[];
  var row = '';
  for (final word in words) {
    if (row.isEmpty) {
      row = word;
    } else if (row.length + 1 + word.length <= _rowWidth) {
      row = '$row $word';
    } else {
      rows.add(row);
      row = word;
    }
  }
  if (row.isNotEmpty) rows.add(row);
  return rows;
}
