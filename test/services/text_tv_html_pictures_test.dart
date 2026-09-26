import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/text_tv_html.dart';
import 'package:flutter_test/flutter_test.dart';

const _whiteOnBlueRight = 693852549; // mask 40 (right side, lower two thirds)
const _whiteOnBlueLower = 2413702233; // mask 60 (lower two thirds)
const _unknown = 111;

String _cell(int hash, {String classes = 'bgB W'}) =>
    '<span class="$classes bgImg" '
    'style="background: url(https://l.texttv.nu/storage/chars/$hash.gif) '
    'center/cover"> </span>';

String _row(String spans) => '<span class="line">$spans</span>';

List<List<StyledRun>> _parse(
  String html, {
  String Function(int page)? commandFor,
}) => parseTextTvHtml(html, columns: 40, commandFor: commandFor)!;

/// A row of [cells] then blanks to 40 wide.
String _rowOf(List<String> cells) => _row(
  '${cells.join()}<span class="bgB">${' ' * (40 - cells.length)}</span>',
);

List<List<StyledRun>> _realPage(String file) {
  final json = jsonDecode(File('test/fixtures/$file').readAsStringSync());
  return _parse(
    (json as List).first['content'].first as String,
    commandFor: (page) => 'texttv $page',
  );
}

void main() {
  group('block graphics', () {
    test('a known picture is a mosaic cell in the colours of the picture', () {
      final row = _parse(_rowOf([_cell(_whiteOnBlueLower)])).single;

      final run = row.first;
      expect(run.mosaic, [60]);
      expect(run.text, ' ');
      expect(run.fg, TvColor.white);
      expect(run.bg, TvColor.blue);
    });

    test('neighbouring cells join into one run, keeping each pattern', () {
      final row = _parse(
        _rowOf([
          _cell(_whiteOnBlueLower),
          _cell(_whiteOnBlueLower),
          _cell(_whiteOnBlueRight),
        ]),
      ).single;

      expect(row.first.mosaic, [60, 60, 40]);
      expect(row.first.text, '   ');
      expect(plainText(row), hasLength(40));
    });

    test('a mosaic run is not joined to a run of text', () {
      final row = _parse(
        _row(
          '${_cell(_whiteOnBlueLower)}'
          '<span class="bgB W">${'x'.padRight(39)}</span>',
        ),
      ).single;

      expect(row.map((run) => run.mosaic == null), [false, true]);
    });

    test('a picture that is not known is a blank in the span\'s colours', () {
      final row = _parse(_rowOf([_cell(_unknown)])).single;

      expect(row.first.mosaic, isNull);
      expect(row.first.text.trim(), isEmpty);
      expect(row.first.bg, TvColor.blue);
    });

    test('a cell with no picture address is a blank too', () {
      final row = _parse(
        _row(
          '<span class="bgB W bgImg"> </span>'
          '<span class="bgB">${' ' * 39}</span>',
        ),
      ).single;

      expect(row.first.mosaic, isNull);
    });

    test('a cell in a headline row is tall like the rest of the row', () {
      final row = _parse(
        '<span style="transform:scaleY(2);" class="line DH">'
        '${_cell(_whiteOnBlueLower)}'
        '<span class="bgB">${' ' * 39}</span></span>',
      ).single;

      expect(row.first.tall, isTrue);
      expect(row.first.mosaic, [60]);
    });
  });

  group('links', () {
    String linkRow(String href, String text) => _row(
      '<span class="bgBl C">ab <a href="$href">$text</a>${' ' * 34}</span>',
    );

    test('a page link tells the command that opens the page', () {
      final row = _parse(
        linkRow('/130', '130'),
        commandFor: (page) => 'texttv $page',
      ).single;

      final link = row.singleWhere((run) => run.underline);
      expect(link.text, '130');
      expect(link.command, 'texttv 130');
      expect(row.where((run) => run.command != null), hasLength(1));
    });

    test('without a way to name the command a link is only underlined', () {
      final link = _parse(linkRow('/130', '130')).single
          .singleWhere((run) => run.underline);

      expect(link.command, isNull);
    });

    test('a link that is not to a page is underlined but not tappable', () {
      final link = _parse(
        linkRow('https://example.com/', 'web'),
        commandFor: (page) => 'texttv $page',
      ).single.singleWhere((run) => run.underline);

      expect(link.command, isNull);
    });
  });

  group('the real front page (100)', () {
    late List<List<StyledRun>> rows;
    setUp(() => rows = _realPage('texttv_100.json'));

    test('the logo rows have block graphics, each row 40 wide', () {
      final logo = rows.sublist(1, 4);

      for (final row in logo) {
        expect(plainText(row), hasLength(40));
      }
      expect(
        logo.any(
          (row) => row.any(
            (run) => run.mosaic != null && run.mosaic!.any((mask) => mask != 0),
          ),
        ),
        isTrue,
      );
    });

    test('the pictures the page names become mosaic cells', () {
      final json = jsonDecode(
        File('test/fixtures/texttv_100.json').readAsStringSync(),
      );
      final html = (json as List).first['content'].first as String;
      final pictures = RegExp('bgImg').allMatches(html).length;
      // Rows a headline covers are dropped, so count what is on screen too.
      final drawn = [
        for (final row in rows)
          for (final run in row)
            if (run.mosaic != null) ...run.mosaic!,
      ];

      expect(pictures, greaterThan(0));
      expect(drawn, isNotEmpty);
      // Rows a headline covers are dropped, so no more than the page names.
      expect(drawn.length, lessThanOrEqualTo(pictures));
    });

    test('its page numbers are links', () {
      final links = [
        for (final row in rows)
          for (final run in row)
            if (run.command != null) run.command,
      ];

      expect(links, isNotEmpty);
      expect(links, contains('texttv 130'));
    });
  });

  test('the real page 377 links its matches', () {
    final rows = _realPage('texttv_377.json');

    final commands = {
      for (final row in rows)
        for (final run in row)
          if (run.command != null) run.command,
    };

    expect(commands, everyElement(startsWith('texttv ')));
    expect(commands, isNotEmpty);
  });
}
