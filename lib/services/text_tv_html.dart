import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/tv_mosaic.dart';

/// Colours in the class names texttv.nu puts on each stretch of text:
/// `bgB W` is white on blue. Background classes start with `bg`; the rest name
/// the text colour (`B` is blue text, `bl` is black text).
const _backgrounds = {
  'bgBl': TvColor.black,
  'bgR': TvColor.red,
  'bgG': TvColor.green,
  'bgY': TvColor.yellow,
  'bgB': TvColor.blue,
  'bgM': TvColor.magenta,
  'bgC': TvColor.cyan,
  'bgW': TvColor.white,
};
const _foregrounds = {
  'bl': TvColor.black,
  'R': TvColor.red,
  'G': TvColor.green,
  'Y': TvColor.yellow,
  'B': TvColor.blue,
  'M': TvColor.magenta,
  'C': TvColor.cyan,
  'W': TvColor.white,
};

// `class` is not always the first attribute: the site writes a double-height
// row as `<span style="..." class="line DH">`.
final _rowStart = RegExp(r'<span\b[^>]*?\bclass="(line[^"]*)"[^>]*>');
final _span = RegExp(r'<span\b([^>]*)>(.*?)</span>', dotAll: true);
final _class = RegExp(r'\bclass="([^"]*)"');
final _picture = RegExp(r'storage/chars/(\d+)\.gif');
final _link = RegExp(r'<a\b([^>]*)>(.*?)</a>', dotAll: true);
final _href = RegExp(r'\bhref="/(\d+)"');
final _tag = RegExp(r'<[^>]*>');

/// One page of texttv.nu's HTML as styled rows, or null when it is not the
/// shape this expects (no rows, a row that is not [columns] wide). Null is the
/// caller's cue to fall back to the plain text, so a change on the site costs
/// the colours and nothing else.
///
/// The site draws each row as `<span class="line">` holding one span per
/// stretch of text, classed with its colours; page-number links are `<a>`
/// inside them. Cells it draws as block graphics (`bgImg`) hold a blank and
/// name a small picture; [tvPictureFor] says what it shows. A picture it does
/// not know comes out as a blank cell in the span's colours.
///
/// [commandFor] turns the page number of a link into the command line a tap on
/// it runs; without it, links are underlined but not tappable.
List<List<StyledRun>>? parseTextTvHtml(
  String html, {
  required int columns,
  String Function(int page)? commandFor,
}) {
  final starts = _rowStart.allMatches(html).toList();
  if (starts.isEmpty) return null;

  final rows = <List<StyledRun>>[];
  var skipping = false;
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : html.length;
    final body = html.substring(starts[i].end, end);
    // A double-height row (`line DH`) is drawn twice as tall and covers the
    // row under it, which the site leaves blank.
    final tall = starts[i][1]!.split(' ').contains('DH');
    final runs = <StyledRun>[];
    for (final span in _span.allMatches(body)) {
      runs.addAll(
        _runsOf(span[1]!, span[2]!, tall: tall, commandFor: commandFor),
      );
    }
    final row = mergeRuns(runs);
    if (plainText(row).length != columns) return null;
    if (skipping) {
      skipping = false;
      // Only the blank row under a headline is covered by it; anything there
      // is content and stays.
      if (plainText(row).trim().isEmpty) continue;
    }
    rows.add(row);
    skipping = tall;
  }
  return rows;
}

/// The runs of one span: its text in the colours its class names, with the
/// text of any link inside it underlined, or a block-graphics cell.
Iterable<StyledRun> _runsOf(
  String attributes,
  String content, {
  required bool tall,
  String Function(int page)? commandFor,
}) sync* {
  final classes = _class.firstMatch(attributes)?[1] ?? '';
  var fg = TvColor.white;
  var bg = TvColor.black;
  for (final name in classes.split(RegExp(r'\s+'))) {
    fg = _foregrounds[name] ?? fg;
    bg = _backgrounds[name] ?? bg;
  }

  if (classes.split(RegExp(r'\s+')).contains('bgImg')) {
    final hash = int.tryParse(_picture.firstMatch(attributes)?[1] ?? '');
    final picture = hash == null ? null : tvPictureFor(hash);
    if (picture != null) {
      final text = _text(content);
      yield StyledRun(
        text,
        fg: picture.fg,
        bg: picture.bg,
        tall: tall,
        mosaic: List.filled(text.runes.length, picture.mask),
      );
      return;
    }
  }

  var from = 0;
  for (final link in _link.allMatches(content)) {
    yield StyledRun(
      _text(content.substring(from, link.start)),
      fg: fg,
      bg: bg,
      tall: tall,
    );
    final page = int.tryParse(_href.firstMatch(link[1]!)?[1] ?? '');
    yield StyledRun(
      _text(link[2]!),
      fg: fg,
      bg: bg,
      underline: true,
      tall: tall,
      command: page == null || commandFor == null ? null : commandFor(page),
    );
    from = link.end;
  }
  yield StyledRun(_text(content.substring(from)), fg: fg, bg: bg, tall: tall);
}

/// Markup removed and the few entities HTML text can carry decoded.
String _text(String html) => html
    .replaceAll(_tag, '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');
