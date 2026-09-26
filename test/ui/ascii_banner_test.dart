import 'package:android_terminal_launcher/ui/ascii_banner.dart';
import 'package:android_terminal_launcher/ui/rocket_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _interval = Duration(milliseconds: 220);

Future<void> _pump(WidgetTester tester, {double width = 400}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: const AsciiBanner(caption: 'hi'),
          ),
        ),
      ),
    ),
  );
}

/// The row of the rocket's tip (`^`) in the frame currently shown.
int _tipRow(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data!)
      .firstWhere((data) => data.contains('\n'));
  return text.split('\n').indexWhere((line) => line.contains('^'));
}

void main() {
  group('the frames', () {
    test('every frame is the same size, so nothing shifts between them', () {
      for (final frame in rocketFrames) {
        expect(frame, hasLength(rocketArtHeight));
        for (final line in frame) {
          expect(line.length, rocketArtWidth, reason: '"$line"');
        }
      }
    });

    test('plain ASCII only, so no other font is ever used', () {
      for (final frame in rocketFrames) {
        for (final line in frame) {
          expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
        }
      }
    });

    test('the rocket only ever goes up, and ends at the top', () {
      final tips = [
        for (final frame in rocketFrames)
          frame.indexWhere((line) => line.contains('^')),
      ];

      for (var i = 1; i < tips.length; i++) {
        expect(tips[i], lessThanOrEqualTo(tips[i - 1]));
      }
      expect(tips.first, greaterThan(tips.last));
      expect(tips.last, 0);
    });

    test('the pad is always at the bottom', () {
      for (final frame in rocketFrames) {
        expect(frame.last, '=' * rocketArtWidth);
      }
    });

    test('the launch is short: it must not keep a timer busy', () {
      expect(
        _interval * rocketFrames.length,
        lessThan(const Duration(seconds: 3)),
      );
    });

    test('the rocket keeps its shape in every frame', () {
      for (final frame in rocketFrames) {
        final body = frame.where((line) => line.contains('|___|')).toList();
        expect(body, hasLength(1));
      }
    });
  });

  group('the widget', () {
    testWidgets('shows the caption and the rocket on the pad', (tester) async {
      await _pump(tester);

      expect(find.text('hi'), findsOneWidget);
      expect(
        _tipRow(tester),
        rocketFrames.first.indexWhere((line) => line.contains('^')),
      );
    });

    testWidgets('lifts off, then stops changing', (tester) async {
      await _pump(tester);
      final start = _tipRow(tester);

      for (var i = 0; i < rocketFrames.length - 1; i++) {
        await tester.pump(_interval);
      }
      final end = _tipRow(tester);
      expect(end, lessThan(start));

      // The timer must have cancelled itself by now: pumping well past it must
      // neither change the frame again nor leave a pending timer behind (which
      // would fail the test on its own).
      await tester.pump(const Duration(seconds: 5));
      expect(_tipRow(tester), end);
    });

    testWidgets('the picture and the caption are centred', (tester) async {
      await _pump(tester, width: 400);

      final picture = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('\n'),
      );
      expect(tester.getCenter(picture).dx, closeTo(200, 1));
      expect(tester.getCenter(find.text('hi')).dx, closeTo(200, 1));
    });

    testWidgets('a long caption wraps centred instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: AsciiBanner(caption: 'a caption that is much too long'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final caption = tester.widget<Text>(
        find.text('a caption that is much too long'),
      );
      expect(caption.textAlign, TextAlign.center);
    });

    testWidgets('leaving the screen mid-launch leaves no timer behind', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump(_interval);

      await tester.pumpWidget(const SizedBox());
      // A leaked periodic timer would fail the test at teardown.
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
