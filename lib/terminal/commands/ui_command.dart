import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/services/view_mode.dart';
import 'package:android_terminal_launcher/services/view_mode_settings.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/choice_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

/// `ui` shows the views (the current one starred), `ui plain` / `ui rich`
/// switches. Only output from then on is affected: what is already on screen
/// stays as it was drawn.
Command uiCommand(ViewModeSettings settings) => Command(
  name: 'ui',
  description: 'Rich views or plain text',
  usage: 'ui [rich|plain]',
  forms: ['ui', 'ui <view>'],
  examples: ['ui plain'],
  notes: ['views: ${ViewMode.values.map((m) => m.name).join(' ')}'],
  run: (context) => _ui(settings, context.args),
  argSuggestions: (partial, apps) => [
    for (final mode in ViewMode.values)
      if (mode.name.startsWith(partial.toLowerCase())) mode.name,
  ],
);

Future<CommandResult> _ui(ViewModeSettings settings, List<String> args) async {
  if (args.isEmpty) {
    return CommandOutput(
      _listing(settings.current),
      block: settingChoices(
        title: 'view',
        command: 'ui',
        current: settings.current.name,
        options: [
          for (final m in ViewMode.values)
            (name: m.name, description: m.description),
        ],
      ),
    );
  }
  if (args.length != 1) return const CommandFailure([Messages.uiUsage]);

  final mode = ViewMode.parse(args.first);
  if (mode == null) {
    return CommandFailure.single(
      Messages.unknownView(
        args.first,
        ViewMode.values.map((m) => m.name).toList(),
      ),
    );
  }
  try {
    await settings.select(mode);
  } on LocalStoreException catch (error) {
    // The view did change, so say so, and say it won't survive a restart.
    return noticeOutput(
      Messages.uiChanged(mode.name),
      kind: NoticeKind.warning,
      details: [Messages.uiNotSaved(error.message)],
    );
  }
  return noticeOutput(Messages.uiChanged(mode.name));
}

List<String> _listing(ViewMode current) {
  final width = ViewMode.values.map((m) => m.name.length).reduce(_max);
  return [
    Messages.uiHeader,
    for (final mode in ViewMode.values)
      '${mode == current ? '*' : ' '} ${mode.name.padRight(width)}  '
          '${mode.description}',
  ];
}

int _max(int a, int b) => a > b ? a : b;
