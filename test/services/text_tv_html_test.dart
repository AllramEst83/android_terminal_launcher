import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/text_tv_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// The HTML of a real page 377 from texttv.nu, reduced to the fields we read.
String _realHtml() {
  final json = jsonDecode(
    File('test/fixtures/texttv_377.json').readAsStringSync(),
  );
  return (json as List).first['content'].first as String;
}

List<List<StyledRun>> _parse(String html) =>
    parseTextTvHtml(html, columns: 40)!;

String _row(String spans) => '<span class="line">$spans</span>';
String _pad(String text) => text.padRight(40);

void main() {
  group('a real page', () {
    late List<List<StyledRun>> rows;
    setUp(() => rows = _parse(_realHtml()));

    test('has a row per line, each exactly 40 columns', () {
      expect(rows, hasLength(24));
      for (final row in rows) {
        expect(plainText(row), hasLength(40), reason: plainText(row));
      }
    });

    test('the top row is white and yellow on black', () {
      final top = rows.first;

      expect(top.first.bg, TvColor.black);
      expect(plainText(top), startsWith('   377 SVT Text '));
      final title = top.firstWhere((run) => run.text.contains('SVT Text'));
      expect(title.fg, TvColor.yellow);
      final number = top.firstWhere((run) => run.text.contains('377'));
      expect(number.fg, TvColor.white);
    });

    test('a title bar is white on blue', () {
      final bar = rows[1].firstWhere((run) => run.text.contains('MÅ'));

      expect(bar.bg, TvColor.blue);
      expect(bar.fg, TvColor.white);
    });

    test('headings are green and results white, on black', () {
      final heading = rows[2].firstWhere((run) => run.text.contains('Fotboll'));

      expect(heading.fg, TvColor.green);
      expect(heading.bg, TvColor.black);
    });

    test('links are underlined and nothing else is', () {
      final underlined = [
        for (final row in rows)
          for (final run in row)
            if (run.underline) run.text,
      ];

      expect(underlined, containsAll(['376', '330']));
      for (final text in underlined) {
        expect(int.tryParse(text), isNotNull, reason: text);
      }
    });

    test('a link keeps the colours of the bar it is in', () {
      final link = rows.last.firstWhere((run) => run.underline);

      expect(link.bg, TvColor.blue);
      expect(link.fg, TvColor.white);
    });

    test('neighbouring stretches of one style are one run', () {
      for (final row in rows) {
        for (var i = 1; i < row.length; i++) {
          expect(
            row[i].sameStyleAs(row[i - 1]),
            isFalse,
            reason: '${row[i - 1]} then ${row[i]}',
          );
        }
      }
    });

    test('the text equals the plain text the site sends', () {
      final json = jsonDecode(
        File('test/fixtures/texttv_377.json').readAsStringSync(),
      );
      final plain = ((json as List).first['content_plain'].first as String)
          .split('\n');

      // The top row has its 3-column margin in the HTML only.
      for (var i = 1; i < rows.length; i++) {
        expect(
          plainText(rows[i]).trimRight(),
          plain[i].trimRight(),
          reason: '$i',
        );
      }
    });
  });

  group('the markup', () {
    test('a class names the colours: bg… is the background', () {
      final rows = _parse(_row('<span class="bgY bl">${_pad('x')}</span>'));

      expect(rows.single.single.bg, TvColor.yellow);
      expect(rows.single.single.fg, TvColor.black);
    });

    test('every colour name is understood', () {
      const backgrounds = {
        'bgBl': TvColor.black,
        'bgR': TvColor.red,
        'bgG': TvColor.green,
        'bgY': TvColor.yellow,
        'bgB': TvColor.blue,
        'bgM': TvColor.magenta,
        'bgC': TvColor.cyan,
        'bgW': TvColor.white,
      };
      const foregrounds = {
        'bl': TvColor.black,
        'R': TvColor.red,
        'G': TvColor.green,
        'Y': TvColor.yellow,
        'B': TvColor.blue,
        'M': TvColor.magenta,
        'C': TvColor.cyan,
        'W': TvColor.white,
      };
      for (final MapEntry(key: bgClass, value: bg) in backgrounds.entries) {
        for (final MapEntry(key: fgClass, value: fg) in foregrounds.entries) {
          final run = _parse(
            _row('<span class="$bgClass $fgClass">${_pad('x')}</span>'),
          ).single.single;

          expect((run.bg, run.fg), (bg, fg), reason: '$bgClass $fgClass');
        }
      }
    });

    test('no colour class means white on black', () {
      final run = _parse(_row('<span class="">${_pad('x')}</span>'))
          .single
          .single;

      expect((run.fg, run.bg), (TvColor.white, TvColor.black));
    });

    test('a mosaic cell is a blank in its colours', () {
      final rows = _parse(
        _row(
          '<span class="bgB W bgImg" style="background: url(x.gif)"> </span>'
          '<span class="bgB">${' ' * 39}</span>',
        ),
      );

      expect(plainText(rows.single), hasLength(40));
      expect(rows.single.single.bg, TvColor.blue);
    });

    test('link text is underlined and the text around it is not', () {
      final rows = _parse(
        _row('<span class="bgBl W">ab <a href="/1">101</a>${' ' * 34}</span>'),
      );

      expect(rows.single.map((r) => (r.text.trim(), r.underline)), [
        ('ab', false),
        ('101', true),
        ('', false),
      ]);
      expect(plainText(rows.single), hasLength(40));
    });

    test('entities are decoded', () {
      final rows = _parse(
        _row(
          '<span class="bgBl W">'
          '${'a&amp;b &lt;c&gt; &quot;d&quot; e&nbsp;f'}${' ' * 25}'
          '</span>',
        ),
      );

      expect(plainText(rows.single), startsWith('a&b <c> "d" e f'));
      expect(plainText(rows.single), hasLength(40));
    });

    test('rows are told apart by their line class, toprow and DH included', () {
      final html =
          '<div class="root">'
          '<span class="line toprow"><span class="bgBl">${_pad('a')}</span></span>\n'
          '<span style="x" class="line DH"><span class="bgBl">${_pad('b')}</span></span>\n'
          '<span class="line"><span class="bgBl">${_pad('c')}</span></span></div>';

      expect(_parse(html).map((row) => plainText(row).trimRight()), [
        'a',
        'b',
        'c',
      ]);
    });
  });

  group('double-height headlines', () {
    String dhRow(String text) =>
        '<span style="display:inline-block;transform:scaleY(2);" class="line DH">'
        '<span class="bgBl Y">${_pad(text)}</span></span>';

    test('a headline row is tall, in every run of it', () {
      final rows = _parse(
        '${dhRow('Big news')}\n${_row('<span class="bgBl">${_pad('')}</span>')}',
      );

      expect(rows.first.every((run) => run.tall), isTrue);
      expect(plainText(rows.first), startsWith('Big news'));
    });

    test('the blank row under it is covered by it, so it is left out', () {
      final rows = _parse(
        '${dhRow('Big news')}\n'
        '${_row('<span class="bgBl">${_pad('')}</span>')}\n'
        '${_row('<span class="bgBl W">${_pad('after')}</span>')}',
      );

      expect(rows.map((r) => plainText(r).trimRight()), ['Big news', 'after']);
    });

    test('a row under it that has text is content, and stays', () {
      final rows = _parse(
        '${dhRow('Big news')}\n'
        '${_row('<span class="bgBl W">${_pad('not blank')}</span>')}',
      );

      expect(rows, hasLength(2));
      expect(rows.last.first.tall, isFalse);
    });

    test('only the row right under a headline is dropped', () {
      final blank = _row('<span class="bgBl">${_pad('')}</span>');
      final rows = _parse('${dhRow('a')}\n$blank\n$blank');

      expect(rows, hasLength(2));
    });

    test('a headline as the last row is fine', () {
      expect(_parse(dhRow('the end')), hasLength(1));
    });

    test('ordinary rows are not tall', () {
      final rows = _parse(_row('<span class="bgBl W">${_pad('x')}</span>'));

      expect(rows.single.single.tall, isFalse);
    });

    test('a tall run is not merged into a normal one', () {
      const normal = StyledRun('a');
      const tall = StyledRun('b', tall: true);

      expect(mergeRuns([normal, tall]), hasLength(2));
      expect(normal.sameStyleAs(tall), isFalse);
    });
  });

  group('a real front page with headlines and a logo', () {
    late List<List<StyledRun>> rows;
    setUp(() {
      final json = jsonDecode(
        File('test/fixtures/texttv_100.json').readAsStringSync(),
      );
      rows = _parse((json as List).first['content'].first as String);
    });

    test('every row is 40 wide, whatever pictures the page has', () {
      for (final row in rows) {
        expect(plainText(row), hasLength(40));
      }
    });

    test('has three headlines, each covering the blank row below it', () {
      final tall = rows.where((row) => row.first.tall).toList();

      expect(tall, hasLength(3));
      expect(plainText(tall.first), contains('Akilov'));
      // 24 rows on the site, three of them hidden under a headline.
      expect(rows, hasLength(24 - 3));
    });

    test('the headline is yellow on black', () {
      final headline = rows.firstWhere(
        (row) => plainText(row).contains('Akilov'),
      );

      final text = headline.firstWhere((run) => run.text.contains('Akilov'));
      expect(text.fg, TvColor.yellow);
      expect(text.bg, TvColor.black);
    });

    test('the picture cells are blanks in their colours, in the logo rows', () {
      // Rows 1-3 are the SVT Text logo drawn as pictures on the site.
      final logo = rows[1];

      expect(plainText(logo).trim(), isEmpty);
      expect(logo.any((run) => run.bg != TvColor.black), isTrue);
    });
  });

  group('anything unexpected is null, so the plain text is used instead', () {
    test('no rows at all', () {
      expect(parseTextTvHtml('<div>hello</div>', columns: 40), isNull);
      expect(parseTextTvHtml('', columns: 40), isNull);
    });

    test('a row of the wrong width', () {
      final html = _row('<span class="bgBl">${'x' * 39}</span>');

      expect(parseTextTvHtml(html, columns: 40), isNull);
    });

    test('one bad row spoils the page: never half colour', () {
      final html =
          '${_row('<span class="bgBl">${_pad('ok')}</span>')}\n'
          '${_row('<span class="bgBl">short</span>')}';

      expect(parseTextTvHtml(html, columns: 40), isNull);
    });

    test('a different width is judged against the width given', () {
      final html = _row('<span class="bgBl">${'x' * 20}</span>');

      expect(parseTextTvHtml(html, columns: 20), isNotNull);
      expect(parseTextTvHtml(html, columns: 40), isNull);
    });
  });
}
