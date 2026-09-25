import 'package:android_terminal_launcher/services/theme_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Two text colours and a background are all a terminal needs; everything else
/// (cursor, suggestion borders, block dividers) is derived from these.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.error,
  });

  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color error;
}

/// Exhaustive on purpose: adding a [ThemeChoice] fails to compile until it has
/// a palette.
_Palette _paletteFor(ThemeChoice choice) => switch (choice) {
  // Green phosphor CRT.
  ThemeChoice.dark => const _Palette(
    brightness: Brightness.dark,
    background: Colors.black,
    foreground: Color(0xFF33FF66),
    error: Color(0xFFFF5555),
  ),
  // Windows 3.1 silver with navy text.
  ThemeChoice.light => const _Palette(
    brightness: Brightness.light,
    background: Color(0xFFC0C0C0),
    foreground: Color(0xFF000080),
    error: Color(0xFFA00000),
  ),
  // Dark roast with latte-coloured text.
  ThemeChoice.coffee => const _Palette(
    brightness: Brightness.dark,
    background: Color(0xFF2A1A10),
    foreground: Color(0xFFE6C79C),
    error: Color(0xFFFF7B54),
  ),
};

/// The theme for [choice]. The launch screen stays black in every theme (see
/// the architecture decisions), so a light theme only appears once Flutter has
/// drawn its first frame.
ThemeData themeFor(ThemeChoice choice) {
  final palette = _paletteFor(choice);
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    fontFamily: 'JetBrainsMono',
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: palette.brightness,
      primary: palette.foreground,
      onPrimary: palette.background,
      secondary: palette.foreground,
      onSecondary: palette.background,
      error: palette.error,
      onError: palette.background,
      surface: palette.background,
      onSurface: palette.foreground,
    ),
    textTheme: ThemeData(brightness: palette.brightness).textTheme.apply(
      fontFamily: 'JetBrainsMono',
      bodyColor: palette.foreground,
      displayColor: palette.foreground,
    ),
  );
}

/// Status and navigation bars that blend into [theme]: transparent status bar,
/// navigation bar in the background colour, icons dark on a light theme.
SystemUiOverlayStyle overlayStyleFor(ThemeData theme) {
  final icons = theme.brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: theme.scaffoldBackgroundColor,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
  );
}
