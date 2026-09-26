/// The text sizes the launcher offers. `ui/theme.dart` maps each to a scale
/// factor applied to the whole text theme, so every screen (log, prompt,
/// suggestions) grows or shrinks together. The saved form is [name], so
/// renaming a value resets that setting.
enum FontSizeChoice {
  small('compact, more fits on screen'),
  normal('the default size'),
  large('easier to read'),
  huge('easiest to read');

  const FontSizeChoice(this.description);

  final String description;

  /// The size called [text], ignoring case; null if there is none.
  static FontSizeChoice? parse(String text) {
    final wanted = text.toLowerCase();
    for (final choice in values) {
      if (choice.name == wanted) return choice;
    }
    return null;
  }
}
