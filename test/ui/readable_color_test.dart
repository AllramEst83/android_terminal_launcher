import 'package:android_terminal_launcher/ui/readable_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

void main() {
  test('contrast is 21 for black on white and 1 for a colour on itself', () {
    expect(contrastRatio(_black, _white), closeTo(21, 0.01));
    expect(contrastRatio(_white, _black), closeTo(21, 0.01));
    expect(contrastRatio(Colors.teal, Colors.teal), 1);
  });

  test('a colour that shows is left alone', () {
    expect(readableOn(Colors.yellow, _black), Colors.yellow);
    expect(
      readableOn(const Color(0xFF0B3D91), _white),
      const Color(0xFF0B3D91),
    );
  });

  test('navy on black is lightened until it shows, keeping its hue', () {
    const navy = Color(0xFF0B1A6B);

    final shown = readableOn(navy, _black);

    expect(contrastRatio(shown, _black), greaterThanOrEqualTo(3));
    expect(
      HSLColor.fromColor(shown).hue,
      closeTo(HSLColor.fromColor(navy).hue, 3),
    );
    expect(shown.computeLuminance(), greaterThan(navy.computeLuminance()));
  });

  test('pale yellow on a light background is darkened', () {
    const pale = Color(0xFFFFF3B0);
    const pink = Color(0xFFFFD1E8);

    final shown = readableOn(pale, pink);

    expect(contrastRatio(shown, pink), greaterThanOrEqualTo(3));
    expect(shown.computeLuminance(), lessThan(pale.computeLuminance()));
  });

  test('the minimum contrast can be raised', () {
    final shown = readableOn(Colors.grey, _black, minContrast: 7);

    expect(contrastRatio(shown, _black), greaterThanOrEqualTo(7));
  });
}
