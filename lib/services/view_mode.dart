/// How output that has a richer form is shown. [rich] draws it as widgets
/// (a calendar grid, an agenda) or in colour (Text TV); [plain] keeps to text
/// lines only, exactly like output that has no richer form. The saved form is
/// [name], so renaming a value resets that setting.
enum ViewMode {
  rich('colour pages, calendars, agendas'),
  plain('text lines only, like a classic terminal');

  const ViewMode(this.description);

  final String description;

  /// The mode called [text], ignoring case; null if there is none.
  static ViewMode? parse(String text) {
    final wanted = text.toLowerCase();
    for (final mode in values) {
      if (mode.name == wanted) return mode;
    }
    return null;
  }
}
