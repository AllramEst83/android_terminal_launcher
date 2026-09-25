/// The themes the launcher ships with. `ui/theme.dart` maps each to colours
/// with an exhaustive `switch`, so a new value cannot be added without a
/// palette. The saved form is [name], so renaming a value resets that setting.
enum ThemeChoice {
  dark('phosphor green on black'),
  light('navy on silver'),
  coffee('latte on espresso');

  const ThemeChoice(this.description);

  final String description;

  /// The theme called [text], ignoring case; null if there is none.
  static ThemeChoice? parse(String text) {
    final wanted = text.toLowerCase();
    for (final choice in values) {
      if (choice.name == wanted) return choice;
    }
    return null;
  }
}
