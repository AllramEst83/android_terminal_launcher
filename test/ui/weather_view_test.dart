import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:android_terminal_launcher/services/font_size_choice.dart';
import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/terminal/blocks.dart';
import 'package:android_terminal_launcher/ui/block_view.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:android_terminal_launcher/ui/weather_icon.dart';
import 'package:android_terminal_launcher/ui/weather_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = WeatherNow(
  kind: WeatherKind.cloudy,
  description: 'Overcast',
  temperature: 16,
  feelsLike: 14,
  windSpeed: '4.8',
  windPoint: 'SW',
  humidity: 86,
);

WeatherDay _day(
  String label,
  int low,
  int high, {
  String? rain,
  WeatherKind kind = WeatherKind.rain,
}) => WeatherDay(
  label: label,
  kind: kind,
  description: 'Light rain',
  low: low,
  high: high,
  rain: rain,
);

WeatherBlock _block({
  String place = 'Gothenburg, Västra Götaland County, Sweden',
  String? note,
  String? source,
  WeatherNow now = _now,
  List<WeatherDay>? days,
}) => WeatherBlock(
  place: place,
  note: note,
  source: source,
  now: now,
  days:
      days ??
      [
        _day('Today', 14, 17, rain: '0.5'),
        _day('Sat', 14, 17),
        _day('Sun', 13, 18, kind: WeatherKind.cloudy),
      ],
);

Future<void> _pump(
  WidgetTester tester,
  WeatherBlock block, {
  ThemeChoice theme = ThemeChoice.dark,
  FontSizeChoice fontSize = FontSizeChoice.normal,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(theme, fontSize),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlockView(block: block, onRun: (_) {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the card', () {
    testWidgets('shows the place, the sky, the temperature and the details', (
      tester,
    ) async {
      await _pump(tester, _block(note: 'no location, showing home'));

      for (final text in [
        'Gothenburg, Västra Götaland County, Sweden',
        'no location, showing home',
        '16°C',
        'Overcast',
        'feels 14°',
        'wind 4.8 m/s SW',
        'humidity 86%',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('credits its source under the days, when it has one', (
      tester,
    ) async {
      await _pump(tester, _block(source: 'SMHI, measured at Göteborg A, 2 km'));

      final credit = find.text('SMHI, measured at Göteborg A, 2 km');
      expect(credit, findsOneWidget);
      expect(
        tester.getTopLeft(credit).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(weatherDayKey('Sun'))).dy - 1,
        ),
      );
    });

    testWidgets('says which provider failed when the better one broke', (
      tester,
    ) async {
      await _pump(
        tester,
        _block(
          source: 'Open-Meteo (SMHI failed: smhi.se did not answer in time)',
        ),
        width: 320,
      );

      expect(
        find.text('Open-Meteo (SMHI failed: smhi.se did not answer in time)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long credit wraps rather than overflowing', (tester) async {
      await _pump(
        tester,
        _block(
          source: 'SMHI, measured at Göteborg-Landvetter Flygplats, 14 km',
        ),
        width: 320,
        fontSize: FontSizeChoice.huge,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('has no note line when there is no note', (tester) async {
      await _pump(tester, _block());

      expect(find.text('no location, showing home'), findsNothing);
    });

    testWidgets('a row per day with its label, low and high', (tester) async {
      await _pump(tester, _block());

      for (final label in ['Today', 'Sat', 'Sun']) {
        expect(find.byKey(weatherDayKey(label)), findsOneWidget);
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('14°'), findsNWidgets(2)); // two lows
      expect(find.text('17°'), findsNWidgets(2));
      expect(find.text('18°'), findsOneWidget);
    });

    testWidgets('rain is shown for the days that have it', (tester) async {
      await _pump(tester, _block());

      expect(find.byKey(weatherRainKey), findsOneWidget);
      expect(find.text('0.5mm'), findsOneWidget);
    });

    testWidgets('rain gives way when the row has no room for it', (
      tester,
    ) async {
      await _pump(tester, _block(), fontSize: FontSizeChoice.huge, width: 320);

      expect(find.byKey(weatherRainKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a forecast with no days is only the current weather', (
      tester,
    ) async {
      await _pump(tester, _block(days: const []));

      expect(find.text('16°C'), findsOneWidget);
      expect(find.byKey(weatherDayKey('Today')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('below zero shows its minus sign', (tester) async {
      await _pump(
        tester,
        _block(
          now: const WeatherNow(
            kind: WeatherKind.snow,
            description: 'Snow',
            temperature: -12,
            feelsLike: -18,
            windSpeed: '7',
            windPoint: 'N',
            humidity: 90,
          ),
          days: [_day('Today', -15, -9)],
        ),
      );

      expect(find.text('-12°C'), findsOneWidget);
      expect(find.text('-15°'), findsOneWidget);
      expect(find.text('-9°'), findsOneWidget);
    });

    testWidgets('is read out in words', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _block());

      expect(
        tester.getSemantics(find.byKey(weatherNowKey)).label,
        'Overcast, 16 degrees, feels like 14',
      );
      expect(
        tester.getSemantics(find.byKey(weatherDayKey('Today'))).label,
        'Today, Light rain, 14 to 17 degrees, 0.5 millimetres of rain',
      );
      expect(
        tester.getSemantics(find.byKey(weatherDayKey('Sat'))).label,
        'Sat, Light rain, 14 to 17 degrees',
      );
      handle.dispose();
    });
  });

  group('the temperature bars', () {
    /// The bar of the day [label]: its offset and length along the track.
    (double, double, double) bar(WidgetTester tester, String label) {
      final positioned = find.descendant(
        of: find.byKey(weatherDayKey(label)),
        matching: find.byType(Positioned),
      );
      // The track is the first, the day's stretch of it the second.
      final track = tester.widget<Positioned>(positioned.at(0));
      final stretch = tester.widget<Positioned>(positioned.at(1));
      final trackWidth = tester.getSize(positioned.at(0)).width;
      expect(track.left, 0); // the track fills the row
      return (stretch.left!, stretch.width!, trackWidth);
    }

    testWidgets('sit along one scale for the whole week', (tester) async {
      await _pump(
        tester,
        _block(days: [_day('Cold', 0, 5), _day('Warm', 5, 10)]),
      );

      final (coldStart, coldLength, track) = bar(tester, 'Cold');
      final (warmStart, warmLength, _) = bar(tester, 'Warm');

      expect(coldStart, 0);
      expect(coldLength, closeTo(track / 2, 0.5));
      expect(warmStart, closeTo(track / 2, 0.5));
      expect(warmLength, closeTo(track / 2, 0.5));
    });

    testWidgets('a week of one temperature fills the track', (tester) async {
      await _pump(tester, _block(days: [_day('Flat', 8, 8)]));

      final (start, length, track) = bar(tester, 'Flat');

      expect(start, 0);
      expect(length, closeTo(track, 0.5));
    });

    testWidgets('a day with the same low and high is still a visible dot', (
      tester,
    ) async {
      await _pump(
        tester,
        _block(days: [_day('Dot', 5, 5), _day('Wide', 0, 10)]),
      );

      final (start, length, track) = bar(tester, 'Dot');

      expect(length, greaterThanOrEqualTo(6));
      expect(start + length, lessThanOrEqualTo(track + 0.01));
    });

    testWidgets('a track narrower than a dot does not break the bar', (
      tester,
    ) async {
      await _pump(tester, _block(days: [_day('Dot', 5, 5)]), width: 40);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a day at the warm end stays inside the track', (tester) async {
      await _pump(
        tester,
        _block(days: [_day('Cool', 0, 1), _day('Hot', 9, 10)]),
      );

      final (start, length, track) = bar(tester, 'Hot');

      expect(start + length, lessThanOrEqualTo(track + 0.01));
    });
  });

  group('every theme at every size, on a narrow screen', () {
    for (final theme in ThemeChoice.values) {
      for (final size in FontSizeChoice.values) {
        testWidgets('${theme.name} ${size.name}: nothing overflows', (
          tester,
        ) async {
          await _pump(
            tester,
            _block(
              place: 'A place with a very long name, County of Somewhere',
              note: 'no location, showing home',
              now: const WeatherNow(
                kind: WeatherKind.thunder,
                description: 'Thunder and hail',
                temperature: -12,
                feelsLike: -18,
                windSpeed: '12.5',
                windPoint: 'NW',
                humidity: 100,
              ),
              days: [
                _day('Today', -15, -9, rain: '12.5'),
                _day('Mon', -5, 25, rain: '0.1'),
                _day('Tue', 0, 0),
                _day('Wed', 30, 31, rain: '100'),
                _day('Thu', -30, 40),
              ],
            ),
            theme: theme,
            fontSize: size,
            width: 320,
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the pictures', () {
    /// The rendered pixels of [kind] in white on black, 64 square.
    Future<Uint8List> render(WidgetTester tester, WeatherKind kind) async {
      const key = ValueKey('icon');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.black,
                child: WeatherIcon(kind: kind, size: 64, color: Colors.white),
              ),
            ),
          ),
        ),
      );
      final image = await tester.runAsync(
        () => tester
            .renderObject<RenderRepaintBoundary>(find.byKey(key))
            .toImage(),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ImageByteFormat.rawRgba),
      );
      return bytes!.buffer.asUint8List();
    }

    int lit(Uint8List rgba) {
      var count = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        if (rgba[i] > 128) count++;
      }
      return count;
    }

    testWidgets('every kind draws something, and not the whole square', (
      tester,
    ) async {
      for (final kind in WeatherKind.values) {
        final pixels = lit(await render(tester, kind));

        expect(pixels, greaterThan(100), reason: '${kind.name} is blank');
        expect(pixels, lessThan(64 * 64 ~/ 2), reason: '${kind.name} is solid');
      }
    });

    testWidgets('every kind looks different from every other', (tester) async {
      final seen = <String, WeatherKind>{};
      for (final kind in WeatherKind.values) {
        final pixels = (await render(tester, kind)).join(',');

        expect(seen[pixels], isNull, reason: '${kind.name} == ${seen[pixels]}');
        seen[pixels] = kind;
      }
    });

    testWidgets('is drawn in the colour it is given', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: WeatherIcon(
              kind: WeatherKind.clear,
              size: 64,
              color: Color(0xFF33FF66),
            ),
          ),
        ),
      );

      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
              as WeatherIconPainter;
      expect(painter.color, const Color(0xFF33FF66));
    });

    test('repaints only when the picture or colour changes', () {
      const painter = WeatherIconPainter(WeatherKind.rain, Colors.white);

      expect(
        painter.shouldRepaint(
          const WeatherIconPainter(WeatherKind.rain, Colors.white),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          const WeatherIconPainter(WeatherKind.snow, Colors.white),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const WeatherIconPainter(WeatherKind.rain, Colors.black),
        ),
        isTrue,
      );
    });

    testWidgets('is not read out (the text beside it says it)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: WeatherIcon(
            kind: WeatherKind.rain,
            size: 64,
            color: Colors.white,
          ),
        ),
      );

      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });
  });
}
