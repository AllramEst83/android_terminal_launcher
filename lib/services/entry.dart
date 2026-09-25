/// One note or todo. Notes never use [done]. Ids are stable: they are never
/// reused after an entry is removed, so `note rm 3` can't hit a different note
/// than the one listed.
class Entry {
  const Entry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.done = false,
  });

  final int id;
  final String text;
  final bool done;
  final DateTime createdAt;

  /// When the text last changed; ticking a todo off does not count.
  final DateTime updatedAt;

  Entry copyWith({String? text, bool? done, DateTime? updatedAt}) => Entry(
    id: id,
    text: text ?? this.text,
    done: done ?? this.done,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    'created': createdAt.toUtc().toIso8601String(),
    'updated': updatedAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] if [json] is not an entry as [toJson] writes it.
  factory Entry.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('entry is not an object');
    final id = json['id'];
    final text = json['text'];
    final done = json['done'] ?? false;
    final created = json['created'];
    final updated = json['updated'];
    if (id is! int ||
        text is! String ||
        done is! bool ||
        created is! String ||
        updated is! String) {
      throw const FormatException('entry has missing or mistyped fields');
    }
    return Entry(
      id: id,
      text: text,
      done: done,
      createdAt: DateTime.parse(created),
      updatedAt: DateTime.parse(updated),
    );
  }
}
