import 'package:flutter/material.dart';

/// WCAG contrast ratio of two colours, 1 (identical) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

/// [color] itself if it can be seen against [background] (contrast at least
/// [minContrast], 3 being the bar for graphics), otherwise the nearest shade of
/// it that can: lighter on a dark background, darker on a light one. Calendar
/// colours are chosen for a white app, so a navy calendar would vanish on the
/// black terminal without this, yet keeps its hue.
Color readableOn(Color color, Color background, {double minContrast = 3}) {
  if (contrastRatio(color, background) >= minContrast) return color;
  final hsl = HSLColor.fromColor(color);
  final lighten = background.computeLuminance() < 0.5;
  for (var step = 1; step <= 20; step++) {
    final lightness = (hsl.lightness + (lighten ? 1 : -1) * step * 0.05).clamp(
      0.0,
      1.0,
    );
    final candidate = hsl.withLightness(lightness).toColor();
    if (contrastRatio(candidate, background) >= minContrast) return candidate;
  }
  return lighten ? Colors.white : Colors.black;
}
