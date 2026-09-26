import 'dart:convert';
import 'dart:io';

import 'package:android_terminal_launcher/messages.dart';
import 'package:android_terminal_launcher/services/network_exception.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/text_tv.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/commands/texttv_command.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_app_repository.dart';
import '../../fakes/fake_http_fetcher.dart';

String _realPage104() =>
    File('test/fixtures/texttv_104.json').readAsStringSync();

String _pageJson(List<String> parts, {Object? next = '2', Object? prev = '1'}) {
  return jsonEncode([
    {'num': '5', 'content_plain': parts, 'next_page': next, 'prev_page': prev},
  ]);
}

class _Rig {
  _Rig() : fetcher = FakeHttpFetcher() {
    fetcher.route('texttv.nu', _pageJson(['hello']));
    command = textTvCommand(TextTv(fetcher: fetcher));
  }

  final FakeHttpFetcher fetcher;
  late final Command command;

  Future<CommandResult> run(List<String> args) => command.run(
    CommandContext(args: args, apps: FakeAppRepository(), commands: const []),
  );

  /// The page number the last request asked for.
  String get requested => fetcher.requests.last.pathSegments.last;
}

List<String> _lines(CommandResult result) => switch (result) {
  CommandOutput(:final lines) => lines,
  CommandFailure(:final lines) => lines,
  CommandClear() => fail('unexpected clear'),
};

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());

  group('which page', () {
    test('no argument opens the front page, 100', () async {
      await rig.run([]);

      expect(rig.requested, '100');
    });

    test('a number opens that page', () async {
      await rig.run(['131']);

      expect(rig.requested, '131');
    });

    test('names open the pages people read', () async {
      for (final (name, page) in [
        ('inrikes', '101'),
        ('utrikes', '104'),
        ('sport', '300'),
        ('nyheter', '100'),
        ('väder', '400'),
        ('vader', '400'),
        ('UTRIKES', '104'),
      ]) {
        await rig.run([name]);

        expect(rig.requested, page, reason: name);
      }
    });

    test('anything outside 100-899, or not a number, is refused before any request', () async {
      for (final bad in ['99', '900', '0', '-5', 'abc', '1.5']) {
        final result = await rig.run([bad]);

        expect(result, isA<CommandFailure>(), reason: bad);
        expect(_lines(result), [
          Messages.textTvBadPage(bad, 100, 899),
        ], reason: bad);
      }
      expect(rig.fetcher.requests, isEmpty);
    });

    test('every name is listed in the help notes', () {
      final notes = rig.command.notes.join(' ');

      for (final name in ['nyheter', 'inrikes', 'utrikes', 'sport', 'väder']) {
        expect(notes, contains(name));
      }
    });

    test('the alias tt works', () {
      expect(rig.command.aliases, contains('tt'));
    });
  });

  group('output', () {
    test('is the page laid out on a 40 column grid', () async {
      rig.fetcher.route('texttv.nu', _realPage104());

      final result = await rig.run(['104']) as CommandOutput;

      expect(result.columns, 40);
      expect(result.lines.first, startsWith('104 SVT Text'));
      expect(result.lines.any((l) => l.contains('Aten:')), isTrue);
    });

    test('ends with the neighbouring pages', () async {
      rig.fetcher.route('texttv.nu', _realPage104());

      final lines = _lines(await rig.run(['104']));

      expect(lines.last, 'prev 103 · next 105');
    });

    test('footer lines fit the 40 column grid', () async {
      rig.fetcher.route(
        'texttv.nu',
        _pageJson(['a', 'b', 'c'], next: '1000', prev: '999'),
      );

      final lines = _lines(await rig.run(['130']));

      for (final line in lines.reversed.take(2)) {
        expect(line.length, lessThanOrEqualTo(40), reason: line);
      }
    });

    test('a page without neighbours has no navigation line', () async {
      rig.fetcher.route(
        'texttv.nu',
        _pageJson(['only'], next: null, prev: null),
      );

      expect(_lines(await rig.run(['130'])), ['only']);
    });
  });

  group('colours', () {
    String real377() =>
        File('test/fixtures/texttv_377.json').readAsStringSync();

    test(
      'a coloured page is a coloured grid, one style list per line',
      () async {
        rig.fetcher.route('texttv.nu', real377());

        final result = await rig.run(['377']) as CommandOutput;

        expect(result.columns, 40);
        expect(result.styles, isNotNull);
        expect(result.styles, hasLength(result.lines.length));
        for (var i = 0; i < result.lines.length; i++) {
          expect(plainText(result.styles![i]), result.lines[i], reason: '$i');
        }
      },
    );

    test(
      'every line is the full 40 columns, so colour runs to the edge',
      () async {
        rig.fetcher.route('texttv.nu', real377());

        final result = await rig.run(['377']) as CommandOutput;

        for (final line in result.lines) {
          expect(line, hasLength(40), reason: line);
        }
      },
    );

    test(
      'the navigation footer is white on black, padded to the edge',
      () async {
        rig.fetcher.route('texttv.nu', real377());

        final result = await rig.run(['377']) as CommandOutput;

        expect(result.lines.last.trimRight(), 'prev 376 · next 378');
        final footer = result.styles!.last;
        expect(plainText(footer), hasLength(40));
        expect(
          footer.every(
            (run) => run.fg == TvColor.white && run.bg == TvColor.black,
          ),
          isTrue,
        );
      },
    );

    test('prev and next are underlined and tap to open that page', () async {
      rig.fetcher.route('texttv.nu', real377());

      final result = await rig.run(['377']) as CommandOutput;

      final links = result.styles!.last.where((run) => run.command != null);
      expect(links.map((run) => (run.text, run.command, run.underline)), [
        ('prev 376', 'texttv 376', true),
        ('next 378', 'texttv 378', true),
      ]);
    });

    test('a page with no colours is plain, as before', () async {
      rig.fetcher.route('texttv.nu', _realPage104());

      final result = await rig.run(['104']) as CommandOutput;

      expect(result.styles, isNull);
      expect(result.columns, 40);
    });
  });

  group('parts', () {
    setUp(() {
      rig.fetcher.route(
        'texttv.nu',
        _pageJson(['first part', 'second part', 'third part']),
      );
    });

    test('shows the first part and says how to get the next', () async {
      final lines = _lines(await rig.run(['130']));

      expect(lines, [
        'first part',
        'prev 1 · part 1/3 · next 2',
        'more: texttv 130 2',
      ]);
    });

    test('a part number picks that part', () async {
      final lines = _lines(await rig.run(['130', '2']));

      expect(lines.first, 'second part');
      expect(lines, contains('more: texttv 130 3'));
    });

    test('the last part has no "more" line', () async {
      final lines = _lines(await rig.run(['130', '3']));

      expect(lines.first, 'third part');
      expect(lines.any((l) => l.startsWith('more:')), isFalse);
    });

    test('a part that does not exist is reported', () async {
      final result = await rig.run(['130', '4']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.textTvNoSuchPart(130, 4, 3)]);
    });

    test('a bad part number is refused before any request', () async {
      for (final bad in ['x', '0', '-1']) {
        final result = await rig.run(['130', bad]);

        expect(_lines(result), [Messages.textTvBadPart(bad)], reason: bad);
      }
      expect(rig.fetcher.requests, isEmpty);
    });

    test('a single-part page says "1 part" when asked for more', () async {
      rig.fetcher.route('texttv.nu', _pageJson(['solo']));

      expect(_lines(await rig.run(['130', '2'])), [
        Messages.textTvNoSuchPart(130, 2, 1),
      ]);
      expect(Messages.textTvNoSuchPart(130, 2, 1), contains('1 part,'));
    });
  });

  group('failures', () {
    test('a page not in broadcast', () async {
      rig.fetcher.route(
        'texttv.nu',
        _pageJson(['550 SVT Text   Sidan ej i sändning']),
      );

      final result = await rig.run(['550']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [Messages.textTvNotBroadcast(550)]);
    });

    test('no connection is reported with the reason', () async {
      rig.fetcher.route(
        'texttv.nu',
        const NetworkException("can't reach texttv.nu (no connection?)"),
      );

      final result = await rig.run(['100']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), [
        Messages.textTvError("can't reach texttv.nu (no connection?)"),
      ]);
    });

    test('too many arguments print the usage', () async {
      final result = await rig.run(['100', '1', '2']);

      expect(result, isA<CommandFailure>());
      expect(_lines(result), Messages.textTvUsage);
      expect(rig.fetcher.requests, isEmpty);
    });
  });

  group('argument suggestions', () {
    test('offer the page names', () {
      final suggest = rig.command.argSuggestions!;

      expect(suggest('u', const []), ['utrikes']);
      expect(suggest('v', const []), ['väder', 'vader']);
      expect(
        suggest('', const []),
        containsAll(['inrikes', 'utrikes', 'sport']),
      );
    });

    test('offer nothing once a page has been chosen', () {
      expect(rig.command.argSuggestions!('130 ', const []), isEmpty);
    });
  });
}
