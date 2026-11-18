class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    this.openingBalance = 0,
    this.iconKey,
  });

  final String id;
  final String name;
  final String type;
  final int sortOrder;
  final bool archived;
  final int createdAt;
  final int openingBalance;
  final String? iconKey;

  Account copyWith({
    String? name,
    String? type,
    int? sortOrder,
    bool? archived,
    int? openingBalance,
    String? iconKey,
    bool clearIcon = false,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      openingBalance: openingBalance ?? this.openingBalance,
      iconKey: clearIcon ? null : (iconKey ?? this.iconKey),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'sort_order': sortOrder,
    'archived': archived ? 1 : 0,
    'created_at': createdAt,
    'opening_balance': openingBalance,
    'icon_key': iconKey,
  };

  factory Account.fromMap(Map<String, Object?> map) => Account(
    id: map['id'] as String,
    name: map['name'] as String,
    type: map['type'] as String,
    sortOrder: map['sort_order'] as int? ?? 0,
    archived: (map['archived'] as int? ?? 0) == 1,
    createdAt: map['created_at'] as int? ?? 0,
    openingBalance: map['opening_balance'] as int? ?? 0,
    iconKey: map['icon_key'] as String?,
  );
}
