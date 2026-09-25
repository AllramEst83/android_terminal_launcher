import 'package:flutter/material.dart';

const _terminalGreen = Color(0xFF33FF66);
const _terminalRed = Color(0xFFFF5555);

/// The app's single theme. Always dark: a launcher must never flash white,
/// whatever the OS dark-mode setting is.
final ThemeData terminalTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'JetBrainsMono',
  scaffoldBackgroundColor: Colors.black,
  colorScheme: const ColorScheme.dark(
    primary: _terminalGreen,
    onPrimary: Colors.black,
    surface: Colors.black,
    onSurface: _terminalGreen,
    error: _terminalRed,
  ),
  textTheme: ThemeData.dark().textTheme.apply(
    fontFamily: 'JetBrainsMono',
    bodyColor: _terminalGreen,
    displayColor: _terminalGreen,
  ),
);
