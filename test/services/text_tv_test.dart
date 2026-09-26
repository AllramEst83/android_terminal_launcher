import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_http_fetcher.dart';

/// A real answer from texttv.nu for page 104, reduced to the fields we read.
String _realPage104() =>
    File('test/fixtures/texttv_104.json').readAsStringSync();

/// A real page 377 with its colours (the `content` HTML beside the plain text).
String _realPage377() =>
    File('test/fixtures/texttv_377.json').readAsStringSync();

String _oneRow() =>
    '<span class="line"><span class="bgBl">${'x' * 40}</span></span>';

String _pageWith(List<String> plain, Object? content) => jsonEncode([
  {
    'num': '5',
    'content_plain': plain,
    'content': content,
    'next_page': '6',
    'prev_page': '4',
  },
]);

String _pageJson(List<String> parts, {Object? next = '2', Object? prev = '1'}) {
  return jsonEncode([
    {'num': '5', 'content_plain': parts, 'next_page': next, 'prev_page': prev},
  ]);
}

TextTv _service(FakeHttpFetcher fetcher) => TextTv(fetcher: fetcher);

Matcher _unreadable() => throwsA(
  isA<NetworkException>().having(
    (e) => e.message,
    'message',
    contains('could not read'),
  ),
);

void main() {
  test('asks texttv.nu for the page as plain text, naming this app', () async {
    final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage104());

    await _service(fetcher).page(104);

    final url = fetcher.requests.single;
    expect(url.scheme, 'https');
    expect(url.host, 'texttv.nu');
    expect(url.path, '/api/get/104');
    expect(url.queryParameters['includePlainTextContent'], '1');
    expect(url.queryParameters['app'], 'android_terminal_launcher');
  });

  test('the app name can be changed', () async {
    final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage104());

    await TextTv(fetcher: fetcher, app: 'other').page(104);

    expect(fetcher.requests.single.queryParameters['app'], 'other');
  });

  group('a real page', () {
    late TextTvPage page;

    setUp(() async {
      final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage104());
      page = (await _service(fetcher).page(104))!;
    });

    test('has its number, one part, and neighbours', () {
      expect(page.number, 104);
      expect(page.parts, hasLength(1));
      expect(page.previous, 103);
      expect(page.next, 105);
    });

    test('is a 24-line grid no wider than 40 columns', () {
      final lines = page.parts.single;

      expect(lines, hasLength(24));
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(TextTv.columns));
      }
    });

    test('keeps the layout: page header first, blank lines between items', () {
      final lines = page.parts.single;

      expect(lines.first, startsWith('104 SVT Text'));
      expect(lines, contains(''));
      expect(lines.any((l) => l.contains('Aten:')), isTrue);
    });

    test('keeps Swedish letters', () {
      expect(page.parts.single.join('\n'), contains('säkerhetsråd'));
    });

    test('lines have no trailing spaces', () {
      for (final line in page.parts.single) {
        expect(line, line.trimRight());
      }
    });
  });

  group('colours', () {
    test(
      'a page with HTML has its rows styled, 40 wide, beside the plain text',
      () async {
        final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage377());

        final page = (await _service(fetcher).page(377))!;

        final styled = page.styledParts!;
        expect(styled, hasLength(page.parts.length));
        expect(styled.single, hasLength(24));
        for (final row in styled.single) {
          expect(plainText(row), hasLength(TextTv.columns));
        }
        expect(page.parts.single.first, startsWith('377 SVT Text'));
      },
    );

    test('rows keep their full width: a bar runs to the edge', () async {
      final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage377());

      final page = (await _service(fetcher).page(377))!;

      final bar = page.styledParts!.single[1];
      expect(bar.last.bg, TvColor.blue);
      expect(plainText(bar), hasLength(40));
    });

    test(
      'a page without HTML has no styles, and is otherwise the same',
      () async {
        final fetcher = FakeHttpFetcher()..route('texttv.nu', _realPage104());

        final page = (await _service(fetcher).page(104))!;

        expect(page.styledParts, isNull);
        expect(page.parts.single, hasLength(24));
      },
    );

    test('HTML that cannot be read costs the colours, not the page', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageWith(['hello'], ['<div>surprise</div>']));

      final page = (await _service(fetcher).page(5))!;

      expect(page.styledParts, isNull);
      expect(page.parts, [
        ['hello'],
      ]);
    });

    test('one unreadable part means no colours for any part', () async {
      final fetcher = FakeHttpFetcher()
        ..route(
          'texttv.nu',
          _pageWith(['a', 'b'], [_oneRow(), '<div>bad</div>']),
        );

      expect((await _service(fetcher).page(5))!.styledParts, isNull);
    });

    test('a different number of HTML and plain parts is not trusted', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageWith(['a', 'b'], [_oneRow()]));

      expect((await _service(fetcher).page(5))!.styledParts, isNull);
    });

    test('content that is not a list is ignored', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageWith(['a'], 'oops'));

      expect((await _service(fetcher).page(5))!.styledParts, isNull);
    });

    test('several parts each get their colours', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageWith(['a', 'b'], [_oneRow(), _oneRow()]));

      final page = (await _service(fetcher).page(5))!;

      expect(page.styledParts, hasLength(2));
    });
  });

  test('a page with several parts keeps them in order', () async {
    final fetcher = FakeHttpFetcher()
      ..route('texttv.nu', _pageJson(['one\nuno', 'two\ndos', 'three']));

    final page = (await _service(fetcher).page(5))!;

    expect(page.parts, [
      ['one', 'uno'],
      ['two', 'dos'],
      ['three'],
    ]);
  });

  test('neighbours may be missing or unreadable', () async {
    final fetcher = FakeHttpFetcher()
      ..route('texttv.nu', _pageJson(['x'], next: null, prev: 'oops'));

    final page = (await _service(fetcher).page(5))!;

    expect(page.next, isNull);
    expect(page.previous, isNull);
  });

  group('a page that does not exist', () {
    test('an empty list means no such page', () async {
      final fetcher = FakeHttpFetcher()..route('texttv.nu', '[]');

      expect(await _service(fetcher).page(999), isNull);
    });

    test('"Sidan ej i sändning" means not in broadcast', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageJson(['999 SVT Text   Sidan ej i sändning']));

      expect(await _service(fetcher).page(999), isNull);
    });

    test('a real page that merely mentions it is still a page', () async {
      final fetcher = FakeHttpFetcher()
        ..route('texttv.nu', _pageJson(['a line\nSidan ej i sändning']));

      expect(await _service(fetcher).page(5), isNotNull);
    });
  });

  group('unexpected answers', () {
    Future<void> expectUnreadable(String body) async {
      final fetcher = FakeHttpFetcher()..route('texttv.nu', body);
      await expectLater(_service(fetcher).page(100), _unreadable());
    }

    test('not JSON', () => expectUnreadable('<html>maintenance</html>'));
    test('JSON that is not a list', () => expectUnreadable('{"error":"x"}'));
    test('a list of something else', () => expectUnreadable('["page"]'));
    test('no plain text', () => expectUnreadable('[{"num":"100"}]'));
    test(
      'plain text that is not a list',
      () => expectUnreadable('[{"content_plain":"x"}]'),
    );
    test(
      'an empty list of parts',
      () => expectUnreadable('[{"content_plain":[]}]'),
    );
    test(
      'parts that are not strings',
      () => expectUnreadable('[{"content_plain":[1,2]}]'),
    );
  });

  test('a network failure passes through unchanged', () async {
    const failure = NetworkException("can't reach texttv.nu (no connection?)");
    final fetcher = FakeHttpFetcher()..route('texttv.nu', failure);

    await expectLater(_service(fetcher).page(100), throwsA(same(failure)));
  });
}
