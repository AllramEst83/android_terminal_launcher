import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/app_info.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_history.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

/// How many lines `history` lists.
const historyListed = 20;

/// `history` lists the commands you use most (they also show as chips above the
/// empty prompt); `history clear` forgets them all.
Command historyCommand(CommandHistory history) => Command(
  name: 'history',
  description: 'Your most-used commands',
  usage: 'history [clear]',
  forms: ['history', 'history clear'],
  examples: ['history', 'history clear'],
  notes: [
    'shown above an empty prompt too',
    'ranked by use, recent use counts',
    '  more; tap one to fill the prompt',
    'sms is never kept; note, todo and',
    '  mail keep only their name',
  ],
  // Looking at the history must not change it.
  history: HistoryPolicy.none,
  run: (context) => _history(history, context.args),
  argSuggestions: _suggestArgs,
);

List<String> _suggestArgs(String partial, List<AppInfo> apps) =>
    'clear'.startsWith(partial.toLowerCase()) && !partial.contains(' ')
    ? const ['clear']
    : const [];

Future<CommandResult> _history(
  CommandHistory history,
  List<String> args,
) async {
  if (args.isEmpty) return _list(history);
  if (args.length == 1 && args.first.toLowerCase() == 'clear') {
    await history.clear();
    return noticeOutput(Messages.historyCleared);
  }
  return const CommandFailure(Messages.historyUsage);
}

CommandResult _list(CommandHistory history) {
  final entries = history.top(historyListed);
  if (entries.isEmpty) {
    return noticeOutput(Messages.historyEmpty, kind: NoticeKind.info);
  }
  return CommandOutput(
    [
      Messages.historyCount(history.length),
      for (final entry in entries) '  ${entry.line}',
    ],
    block: ChoiceBlock(
      title: Messages.historyCount(history.length),
      layout: ChoiceLayout.rows,
      footer: Messages.historyFooter,
      groups: [
        ChoiceGroup(
          options: [
            // Filled, not run: a tap must never do a thing the user has not
            // looked at first, and the line may need a change.
            for (final entry in entries)
              ChoiceOption(label: entry.line, command: entry.line, fill: true),
          ],
        ),
      ],
    ),
  );
}
