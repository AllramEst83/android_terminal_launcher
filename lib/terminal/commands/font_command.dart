import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/font_size_settings.dart';
import 'package:android_terminal_launcher/services/local_store_exception.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/tools/choice_blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/notice.dart';

/// `font` lists the sizes (the current one starred), `font <size>` switches.
/// Takes effect at once, redrawing everything already on screen at the new
/// size, the same way a `theme` change redraws it in the new colours.
Command fontCommand(FontSizeSettings settings) => Command(
  name: 'font',
  description: 'Show or change the text size',
  usage: 'font [size]',
  forms: ['font', 'font <size>'],
  examples: ['font large'],
  notes: ['sizes: ${FontSizeChoice.values.map((c) => c.name).join(' ')}'],
  run: (context) => _font(settings, context.args),
  argSuggestions: (partial, apps) => [
    for (final value in ['list', ...FontSizeChoice.values.map((c) => c.name)])
      if (value.startsWith(partial.toLowerCase())) value,
  ],
);

Future<CommandResult> _font(
  FontSizeSettings settings,
  List<String> args,
) async {
  if (args.isEmpty ||
      (args.length == 1 && args.first.toLowerCase() == 'list')) {
    return CommandOutput(
      _listing(settings.current),
      block: settingChoices(
        title: 'font size',
        command: 'font',
        current: settings.current.name,
        options: [
          for (final c in FontSizeChoice.values)
            (name: c.name, description: c.description),
        ],
      ),
    );
  }
  if (args.length != 1) return const CommandFailure([Messages.fontUsage]);

  final choice = FontSizeChoice.parse(args.first);
  if (choice == null) {
    return CommandFailure.single(
      Messages.unknownFontSize(
        args.first,
        FontSizeChoice.values.map((c) => c.name).toList(),
      ),
    );
  }
  try {
    await settings.select(choice);
  } on LocalStoreException catch (error) {
    // The size did change, so say so, and say it won't survive a restart.
    return noticeOutput(
      Messages.fontChanged(choice.name),
      kind: NoticeKind.warning,
      details: [Messages.fontNotSaved(error.message)],
    );
  }
  return noticeOutput(Messages.fontChanged(choice.name));
}

List<String> _listing(FontSizeChoice current) {
  final width = FontSizeChoice.values.map((c) => c.name.length).reduce(_max);
  return [
    Messages.fontHeader,
    for (final choice in FontSizeChoice.values)
      '${choice == current ? '*' : ' '} ${choice.name.padRight(width)}  '
          '${choice.description}',
  ];
}

int _max(int a, int b) => a > b ? a : b;
