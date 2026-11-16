class MoneyCategory {
  const MoneyCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    this.iconId,
  });

  final String id;
  final String name;
  final String kind;
  final int sortOrder;
  final bool archived;
  final int createdAt;
  final String? iconId;

  MoneyCategory copyWith({
    String? name,
    int? sortOrder,
    bool? archived,
    String? iconId,
    bool clearIcon = false,
  }) {
    return MoneyCategory(
      id: id,
      name: name ?? this.name,
      kind: kind,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      iconId: clearIcon ? null : (iconId ?? this.iconId),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind,
    'sort_order': sortOrder,
    'archived': archived ? 1 : 0,
    'created_at': createdAt,
    'icon_id': iconId,
  };

  factory MoneyCategory.fromMap(Map<String, Object?> map) => MoneyCategory(
    id: map['id'] as String,
    name: map['name'] as String,
    kind: map['kind'] as String,
    sortOrder: map['sort_order'] as int? ?? 0,
    archived: (map['archived'] as int? ?? 0) == 1,
    createdAt: map['created_at'] as int? ?? 0,
    iconId: map['icon_id'] as String?,
  );
}
