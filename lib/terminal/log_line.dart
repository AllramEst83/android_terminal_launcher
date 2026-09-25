enum LogKind { input, output, error }

class LogLine {
  const LogLine({required this.id, required this.kind, required this.text});

  /// Unique and increasing, so the UI has stable keys even after the session
  /// drops old lines from the front.
  final int id;
  final LogKind kind;
  final String text;
}
