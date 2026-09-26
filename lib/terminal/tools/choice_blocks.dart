import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/terminal/tools/quote.dart';

/// The choices of a setting (`theme`, `font`, `ui`) as rows, the current one
/// marked. A tap runs `<command> <name>`: switching is harmless and undone by
/// picking another.
ChoiceBlock settingChoices({
  required String title,
  required String command,
  required Iterable<({String name, String description})> options,
  required String current,
}) => ChoiceBlock(
  title: title,
  layout: ChoiceLayout.rows,
  groups: [
    ChoiceGroup(
      options: [
        for (final option in options)
          ChoiceOption(
            label: option.name,
            description: option.description,
            selected: option.name == current,
            command: '$command ${quoteArg(option.name)}',
          ),
      ],
    ),
  ],
);
