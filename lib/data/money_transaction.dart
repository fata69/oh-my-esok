class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.amount,
    required this.kind,
    required this.accountId,
    required this.date,
    required this.createdAt,
    this.categoryId,
    this.toAccountId,
    this.time,
    this.note,
    this.detail,
  });

  final String id;
  final int amount;
  final String kind;
  final String? categoryId;
  final String accountId;
  final String? toAccountId;
  final String date;
  final String? time;
  final String? note;
  final String? detail;
  final int createdAt;

  bool get isExpense => kind == 'expense';
  bool get isIncome => kind == 'income';
  bool get isTransfer => kind == 'transfer';

  MoneyTransaction copyWith({
    int? amount,
    String? kind,
    String? categoryId,
    bool clearCategory = false,
    String? accountId,
    String? toAccountId,
    bool clearToAccount = false,
    String? date,
    String? time,
    bool clearTime = false,
    String? note,
    bool clearNote = false,
    String? detail,
    bool clearDetail = false,
  }) {
    return MoneyTransaction(
      id: id,
      amount: amount ?? this.amount,
      kind: kind ?? this.kind,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      accountId: accountId ?? this.accountId,
      toAccountId: clearToAccount ? null : (toAccountId ?? this.toAccountId),
      date: date ?? this.date,
      time: clearTime ? null : (time ?? this.time),
      note: clearNote ? null : (note ?? this.note),
      detail: clearDetail ? null : (detail ?? this.detail),
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'amount': amount,
    'kind': kind,
    'category_id': categoryId,
    'account_id': accountId,
    'to_account_id': toAccountId,
    'date': date,
    'time': time,
    'note': note,
    'detail': detail,
    'created_at': createdAt,
  };

  factory MoneyTransaction.fromMap(Map<String, Object?> map) =>
      MoneyTransaction(
        id: map['id'] as String,
        amount: map['amount'] as int? ?? 0,
        kind: map['kind'] as String? ?? 'expense',
        categoryId: map['category_id'] as String?,
        accountId: map['account_id'] as String? ?? '',
        toAccountId: map['to_account_id'] as String?,
        date: map['date'] as String? ?? '',
        time: map['time'] as String?,
        note: map['note'] as String?,
        detail: map['detail'] as String?,
        createdAt: map['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'kind': kind,
    'categoryId': categoryId,
    'accountId': accountId,
    'toAccountId': toAccountId,
    'date': date,
    'time': time,
    'note': note,
    'detail': detail,
    'createdAt': createdAt,
  };

  factory MoneyTransaction.fromJson(Map<String, Object?> json) =>
      MoneyTransaction(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        kind: json['kind'] as String? ?? 'expense',
        categoryId: json['categoryId'] as String?,
        accountId: json['accountId'] as String? ?? '',
        toAccountId: json['toAccountId'] as String?,
        date: json['date'] as String? ?? '',
        time: json['time'] as String?,
        note: json['note'] as String?,
        detail: json['detail'] as String?,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      );
}
