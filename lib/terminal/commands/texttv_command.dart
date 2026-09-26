import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';

/// Names for the pages people actually open. Everything else is a number.
const _shortcuts = {
  'nyheter': 100,
  'inrikes': 101,
  'utrikes': 104,
  'sport': 300,
  'väder': 400,
  'vader': 400,
};

/// Text TV pages run from 100 to 899.
const _firstPage = 100;
const _lastPage = 899;

/// `texttv [page|name] [part]`: `texttv 104`, `texttv utrikes`, `texttv 130 2`.
Command textTvCommand(TextTv textTv) => Command(
  name: 'texttv',
  aliases: ['tt'],
  description: 'Read Swedish Text TV',
  usage: 'texttv [page]',
  forms: ['texttv', 'texttv <page>', 'texttv <page> <part>', 'texttv <name>'],
  examples: ['texttv 100', 'texttv utrikes', 'texttv 130 2'],
  notes: [
    'pages $_firstPage-$_lastPage; some have parts',
    'names: nyheter inrikes utrikes',
    '  sport väder',
  ],
  run: (context) => _texttv(textTv, context.args),
  spinner: true,
  argSuggestions: (partial, apps) => [
    if (!partial.contains(' '))
      for (final name in _shortcuts.keys)
        if (name.startsWith(partial.toLowerCase())) name,
  ],
);

Future<CommandResult> _texttv(TextTv textTv, List<String> args) async {
  if (args.length > 2) return const CommandFailure(Messages.textTvUsage);

  final requested = args.isEmpty ? '100' : args.first;
  final number = _shortcuts[requested.toLowerCase()] ?? int.tryParse(requested);
  if (number == null || number < _firstPage || number > _lastPage) {
    return CommandFailure.single(
      Messages.textTvBadPage(requested, _firstPage, _lastPage),
    );
  }
  var part = 1;
  if (args.length == 2) {
    final parsed = int.tryParse(args[1]);
    if (parsed == null || parsed < 1) {
      return CommandFailure.single(Messages.textTvBadPart(args[1]));
    }
    part = parsed;
  }

  final TextTvPage? page;
  try {
    page = await textTv.page(number);
  } on NetworkException catch (error) {
    return CommandFailure.single(Messages.textTvError(error.message));
  }
  if (page == null) {
    return CommandFailure.single(Messages.textTvNotBroadcast(number));
  }
  if (part > page.parts.length) {
    return CommandFailure.single(
      Messages.textTvNoSuchPart(number, part, page.parts.length),
    );
  }

  final footer = _footer(page, part);
  final coloured = page.styledParts?[part - 1];
  if (coloured != null) {
    // The footer is white on black like the rest of the screen, padded to the
    // full width so its row is black to the edge as well.
    final rows = [...coloured, for (final line in footer) _padded(line)];
    return CommandOutput(
      [for (final row in rows) plainText(row)],
      columns: TextTv.columns,
      styles: rows,
    );
  }
  return CommandOutput([
    ...page.parts[part - 1],
    for (final line in footer) plainText(line),
  ], columns: TextTv.columns);
}

/// Navigation lines, kept inside the page's 40 columns so they line up. The
/// pages they name are underlined and tap to open.
List<List<StyledRun>> _footer(TextTvPage page, int part) {
  final parts = page.parts.length;
  StyledRun link(String text, String command) =>
      StyledRun(text, underline: true, command: command);
  final near = [
    if (page.previous != null)
      [link('prev ${page.previous}', 'texttv ${page.previous}')],
    if (parts > 1) [StyledRun('part $part/$parts')],
    if (page.next != null) [link('next ${page.next}', 'texttv ${page.next}')],
  ];
  return [
    if (near.isNotEmpty)
      [
        for (var i = 0; i < near.length; i++) ...[
          if (i > 0) const StyledRun(' · '),
          ...near[i],
        ],
      ],
    if (part < parts)
      [
        link(
          'more: texttv ${page.number} ${part + 1}',
          'texttv ${page.number} ${part + 1}',
        ),
      ],
  ];
}

/// [line] with blanks added to fill the page's width, so its row is black to
/// the edge like the rest of the screen.
List<StyledRun> _padded(List<StyledRun> line) {
  final missing = TextTv.columns - plainText(line).length;
  return [...line, if (missing > 0) StyledRun(' ' * missing)];
}
