/// One entry in the suggestion list.
class Suggestion {
  const Suggestion({required this.label, required this.completion});

  /// What the chip shows.
  final String label;

  /// The whole input line to put in the field when the suggestion is chosen.
  /// Filled, never run, so the user can still edit or add arguments.
  final String completion;

  @override
  bool operator ==(Object other) =>
      other is Suggestion &&
      other.label == label &&
      other.completion == completion;

  @override
  int get hashCode => Object.hash(label, completion);

  @override
  String toString() => 'Suggestion($label -> "$completion")';
}
