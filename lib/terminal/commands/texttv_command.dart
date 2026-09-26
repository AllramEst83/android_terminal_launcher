import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
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

  return CommandOutput([
    ...page.parts[part - 1],
    ..._footer(page, part),
  ], columns: TextTv.columns);
}

/// Navigation lines, kept inside the page's 40 columns so they line up.
List<String> _footer(TextTvPage page, int part) {
  final parts = page.parts.length;
  final near = [
    if (page.previous != null) 'prev ${page.previous}',
    if (parts > 1) 'part $part/$parts',
    if (page.next != null) 'next ${page.next}',
  ];
  return [
    if (near.isNotEmpty) near.join(' · '),
    if (part < parts) 'more: texttv ${page.number} ${part + 1}',
  ];
}
