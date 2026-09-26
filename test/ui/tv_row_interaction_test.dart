import 'dart:ui' show ImageByteFormat;

import 'package:android_terminal_launcher/app.dart';
import 'package:android_terminal_launcher/services/font_size_controller.dart';
import 'package:android_terminal_launcher/services/styled_text.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/services/theme_controller.dart';
import 'package:android_terminal_launcher/terminal/command.dart';
import 'package:android_terminal_launcher/terminal/command_registry.dart';
import 'package:android_terminal_launcher/terminal/command_result.dart';
import 'package:android_terminal_launcher/terminal/terminal_session.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:android_terminal_launcher/ui/tv_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_app_repository.dart';
import '../fakes/in_memory_local_store.dart';

const _columns = 20;
const _shot = ValueKey('shot');

StyledRun _pad(int cells) => StyledRun(' ' * cells);

/// `see 123 and 456` with both numbers links, padded to [_columns].
final _linkRow = [
  const StyledRun('see '),
  const StyledRun('123', underline: true, command: 'go 123'),
  const StyledRun(' and '),
  const StyledRun('456', underline: true, command: 'go 456'),
  _pad(_columns - 15),
];

Future<List<String>> _pumpRow(
  WidgetTester tester,
  List<StyledRun> runs, {
  bool tappable = true,
}) async {
  tester.view.physicalSize = const Size(400, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ran = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(ThemeChoice.dark),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _shot,
            child: TvRow(
              runs: runs,
              columns: _columns,
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
              onRun: tappable ? ran.add : null,
            ),
          ),
        ),
      ),
    ),
  );
  return ran;
}

/// The point in the row where cell [column] (fractions allowed) is.
Offset _at(WidgetTester tester, double column) {
  final rect = tester.getRect(find.byType(TvRow));
  final cell = rect.width / (_columns + tvGutterCells);
  return Offset(
    rect.left + (column + tvGutterLeftCells) * cell,
    rect.center.dy,
  );
}

RenderObject _canvas(WidgetTester tester) => tester.renderObject(
  find.descendant(of: find.byType(TvRow), matching: find.byType(CustomPaint)),
);

void main() {
  group('tvCommandAt', () {
    test('finds the command of the run under the column', () {
      expect(tvCommandAt(_linkRow, 4.5), 'go 123');
      expect(tvCommandAt(_linkRow, 6.9), 'go 123');
      expect(tvCommandAt(_linkRow, 12.5), 'go 456');
    });

    test('a tap just off a link still counts, half a cell off or so', () {
      expect(tvCommandAt(_linkRow, 3.5), 'go 123');
      expect(tvCommandAt(_linkRow, 7.5), 'go 123');
    });

    test('a tap well away from every link is nothing', () {
      expect(tvCommandAt(_linkRow, 0.5), isNull);
      expect(tvCommandAt(_linkRow, 18.5), isNull);
    });

    test('a tap between two links goes to the nearer one', () {
      // "123" ends at 7, "456" starts at 12: 9 is 2 from the first.
      expect(tvCommandAt(_linkRow, 7.4), 'go 123');
      expect(tvCommandAt(_linkRow, 11.6), 'go 456');
    });

    test('a row with no links has no command', () {
      expect(tvCommandAt([const StyledRun('plain text')], 3), isNull);
    });
  });

  group('tapping', () {
    testWidgets('a link runs its command', (tester) async {
      final ran = await _pumpRow(tester, _linkRow);

      await tester.tapAt(_at(tester, 5));
      await tester.tapAt(_at(tester, 13));

      expect(ran, ['go 123', 'go 456']);
    });

    testWidgets('a tap next to a link runs it', (tester) async {
      final ran = await _pumpRow(tester, _linkRow);

      await tester.tapAt(_at(tester, 7.6));

      expect(ran, ['go 123']);
    });

    testWidgets('a tap on plain text does nothing', (tester) async {
      final ran = await _pumpRow(tester, _linkRow);

      await tester.tapAt(_at(tester, 0.5));
      await tester.tapAt(_at(tester, 18.5));

      expect(ran, isEmpty);
    });

    testWidgets('without a way to run commands nothing is tappable', (
      tester,
    ) async {
      final ran = await _pumpRow(tester, _linkRow, tappable: false);

      await tester.tapAt(_at(tester, 5));

      expect(ran, isEmpty);
    });
  });

  group('block graphics', () {
    final black = tvColorOf(TvColor.black);
    final blue = tvColorOf(TvColor.blue);
    final white = tvColorOf(TvColor.white);

    List<StyledRun> cell(List<int> masks) => [
      StyledRun(
        ' ' * masks.length,
        fg: TvColor.white,
        bg: TvColor.blue,
        mosaic: masks,
      ),
      _pad(_columns - masks.length),
    ];

    testWidgets('a lit cell paints its sixths in the foreground colour', (
      tester,
    ) async {
      await _pumpRow(tester, cell([12]));

      // The black screen, the blue ground, then the bar across the middle:
      // two lit sixths.
      expect(
        _canvas(tester),
        paints
          ..rect(color: black)
          ..rect(color: blue)
          ..rect(color: white)
          ..rect(color: white),
      );
    });

    testWidgets('a cell with nothing lit paints only its ground', (
      tester,
    ) async {
      await _pumpRow(tester, cell([0]));

      expect(_canvas(tester), isNot(paints..rect(color: white)));
    });

    testWidgets('a mosaic cell is not also drawn as a character', (
      tester,
    ) async {
      await _pumpRow(tester, cell([63]));

      expect(_canvas(tester), isNot(paints..paragraph()));
    });

    testWidgets('every lit sixth is its own rectangle', (tester) async {
      await _pumpRow(tester, cell([63]));

      expect(
        _canvas(tester),
        paints
          ..rect(color: black)
          ..rect(color: blue)
          ..rect(color: white)
          ..rect(color: white)
          ..rect(color: white)
          ..rect(color: white)
          ..rect(color: white)
          ..rect(color: white),
      );
    });

    /// The colour at the middle of sixth [bit] of the first cell, read back
    /// from the rendered row.
    Future<Color> pixelOf(WidgetTester tester, int mask, int bit) async {
      await _pumpRow(tester, cell([mask]));
      final row = find.byType(TvRow);
      final size = tester.getSize(row);
      final image = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_shot),
        );
        return boundary.toImage();
      });
      final bytes = (await tester.runAsync(
        () => image!.toByteData(format: ImageByteFormat.rawRgba),
      ))!;
      final cellWidth = size.width / (_columns + tvGutterCells);
      final rowOf = bit ~/ 2;
      final columnOf = bit % 2;
      final x =
          cellWidth * tvGutterLeftCells +
          (columnOf == 0 ? cellWidth * 3 / 13 : cellWidth * 9.5 / 13);
      final y = size.height * const [2.5 / 16, 8 / 16, 13.5 / 16][rowOf];
      // The image is of the row alone, so the point is relative to it.
      final px = x.round();
      final py = y.round();
      final at = (py * image!.width + px) * 4;
      return Color.fromARGB(
        255,
        bytes.getUint8(at),
        bytes.getUint8(at + 1),
        bytes.getUint8(at + 2),
      );
    }

    testWidgets('each bit lights its own sixth, and only that one', (
      tester,
    ) async {
      for (var lit = 0; lit < 6; lit++) {
        for (var probe = 0; probe < 6; probe++) {
          final colour = await pixelOf(tester, 1 << lit, probe);

          expect(
            colour,
            probe == lit ? white : blue,
            reason: 'bit $lit lit, looking at sixth $probe',
          );
        }
      }
    });

    testWidgets('a cell with all six lit is white all over', (tester) async {
      for (var probe = 0; probe < 6; probe++) {
        expect(await pixelOf(tester, 63, probe), white);
      }
    });
  });

  group('gutter', () {
    /// A page as the site draws them: column 0 blank, a blue bar over the
    /// rest. Returns the colour at each x in [xs] (pixels), mid-height.
    Future<List<Color>> read(
      WidgetTester tester,
      List<double> Function(double width) xsFor,
    ) async {
      await _pumpRow(tester, [
        const StyledRun(' '),
        StyledRun(' ' * (_columns - 1), bg: TvColor.blue),
      ]);
      final width = tester.getSize(find.byType(TvRow)).width;
      final image = await tester.runAsync(
        () => tester
            .renderObject<RenderRepaintBoundary>(find.byKey(_shot))
            .toImage(),
      );
      final bytes = (await tester.runAsync(
        () => image!.toByteData(format: ImageByteFormat.rawRgba),
      ))!;
      return [
        for (final x in xsFor(width))
          () {
            final index = ((image!.height ~/ 2) * image.width + x.round()) * 4;
            return Color.fromARGB(
              255,
              bytes.getUint8(index),
              bytes.getUint8(index + 1),
              bytes.getUint8(index + 2),
            );
          }(),
      ];
    }

    /// How wide the black is at the left and at the right of the bar.
    Future<(double, double)> margins(WidgetTester tester) async {
      final colours = await read(
        tester,
        (width) => [for (var x = 0; x < width; x++) x.toDouble()],
      );
      final width = colours.length.toDouble();
      final black = tvColorOf(TvColor.black);
      final first = colours.indexWhere((c) => c != black);
      final last = colours.lastIndexWhere((c) => c != black);
      return (first.toDouble(), width - 1 - last);
    }

    testWidgets('the visible margins either side of the bar are equal', (
      tester,
    ) async {
      final (left, right) = await margins(tester);

      expect(left, greaterThan(3));
      expect((left - right).abs(), lessThanOrEqualTo(2));
    });

    testWidgets('and stay equal on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(250, 400);
      final (left, right) = await margins(tester);

      expect(left, greaterThan(3));
      expect((left - right).abs(), lessThanOrEqualTo(2));
    });

    testWidgets('the first and last cells of a full-width bar are not lost', (
      tester,
    ) async {
      final colours = await read(tester, (width) => [width / 2, width - 1]);

      expect(colours.first, tvColorOf(TvColor.blue));
      expect(colours.last, tvColorOf(TvColor.black));
    });
  });

  group('through the log', () {
    final tv = Command(
      name: 'tv',
      description: 'a page with a link',
      usage: 'tv',
      run: (context) async => CommandOutput(
        [plainText(_linkRow)],
        columns: _columns,
        styles: [_linkRow],
      ),
    );
    final go = Command(
      name: 'go',
      description: 'opens a page',
      usage: 'go <n>',
      run: (context) async => CommandOutput(['page ${context.args.first}']),
    );

    testWidgets('tapping a link runs its command like typed input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = InMemoryLocalStore();
      final themes = ThemeController(store: store);
      addTearDown(themes.dispose);
      final fontSize = FontSizeController(store: store);
      addTearDown(fontSize.dispose);
      final session = TerminalSession(
        registry: CommandRegistry([tv, go]),
        apps: FakeAppRepository(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        App(session: session, themes: themes, fontSize: fontSize),
      );
      await tester.enterText(find.byType(TextField), 'tv');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tapAt(_at(tester, 5));
      await tester.pump();
      await tester.pump();

      expect(session.lines.map((l) => l.text), contains(r'$ go 123'));
      expect(session.lines.last.text, 'page 123');
    });
  });
}
