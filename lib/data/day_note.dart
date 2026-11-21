class DayNote {
  const DayNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final int createdAt;
  final int updatedAt;

  String get displayTitle =>
      title.trim().isEmpty ? body.trim().split('\n').first.trim() : title;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory DayNote.fromMap(Map<String, Object?> map) => DayNote(
    id: map['id'] as String,
    title: map['title'] as String,
    body: map['body'] as String,
    createdAt: map['created_at'] as int,
    updatedAt: map['updated_at'] as int,
  );
}
