/// Lets something outside the prompt (a button in a card in the log) put text
/// in it. The prompt attaches itself; until it does, or after it is gone,
/// [fill] does nothing.
class PromptFiller {
  void Function(String text)? _handler;

  /// Called by the prompt when it appears.
  void attach(void Function(String text) handler) => _handler = handler;

  /// Called by the prompt when it goes away. Only detaches [handler], so a
  /// newer prompt that has already attached is left alone.
  void detach(void Function(String text) handler) {
    if (_handler == handler) _handler = null;
  }

  /// Puts [text] in the prompt, cursor at its end, and focuses it.
  void fill(String text) => _handler?.call(text);
}
