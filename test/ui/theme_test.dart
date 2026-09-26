import 'dart:math' as math;

import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:android_terminal_launcher/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final choice in ThemeChoice.values) {
    group('${choice.name} theme', () {
      final theme = themeFor(choice);

      test('text is readable on the background (WCAG AA)', () {
        expect(
          _contrast(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('errors are readable on the background (WCAG AA)', () {
        expect(
          _contrast(theme.colorScheme.error, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('body text uses the bundled font and the text colour', () {
        expect(theme.textTheme.bodyLarge?.fontFamily, 'JetBrainsMono');
        expect(theme.textTheme.bodyLarge?.color, theme.colorScheme.onSurface);
      });

      test('the system bars match the background', () {
        final overlay = overlayStyleFor(theme);

        expect(overlay.systemNavigationBarColor, theme.scaffoldBackgroundColor);
        expect(
          overlay.statusBarIconBrightness,
          theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );
      });
    });
  }

  test('every theme looks different', () {
    final backgrounds = {
      for (final c in ThemeChoice.values) themeFor(c).scaffoldBackgroundColor,
    };
    final foregrounds = {
      for (final c in ThemeChoice.values) themeFor(c).colorScheme.onSurface,
    };

    expect(backgrounds, hasLength(ThemeChoice.values.length));
    expect(foregrounds, hasLength(ThemeChoice.values.length));
  });

  test('dark stays pure black, so it matches the native launch screen', () {
    expect(themeFor(ThemeChoice.dark).scaffoldBackgroundColor, Colors.black);
  });

  test('only light and pastel are light themes', () {
    expect(
      ThemeChoice.values.where(
        (c) => themeFor(c).brightness == Brightness.light,
      ),
      [ThemeChoice.light, ThemeChoice.pastel],
    );
  });
}
