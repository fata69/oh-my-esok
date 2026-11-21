String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

int daysBetween(DateTime from, DateTime to) {
  final a = dateOnly(from);
  final b = dateOnly(to);
  return b.difference(a).inDays;
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.scheduledDate,
    required this.isDone,
    required this.createdAt,
    this.scheduledTime,
    this.notes,
    this.repeatWeekdays = const [],
    this.seriesId,
    this.repeatUntil,
    this.isSkipped = false,
    this.isProjected = false,
  });

  final String id;
  final String title;
  final String scheduledDate;
  final String? scheduledTime;
  final String? notes;
  final bool isDone;
  final int createdAt;
  final List<int> repeatWeekdays;

  /// An exclusive end date for a stored rule segment.
  final String? repeatUntil;
  final String? seriesId;
  final bool isSkipped;
  final bool isProjected;

  bool get isRecurring => repeatWeekdays.isNotEmpty || seriesId != null;
  bool get isOccurrence => seriesId != null && id.startsWith('occ:');
  bool get isRepeatRule => repeatWeekdays.isNotEmpty && !isOccurrence;
  String get recurrenceId => seriesId ?? id;
  String get occurrenceDay =>
      isOccurrence ? id.substring(id.length - 10) : scheduledDate;

  static String occurrenceId(String series, String day) => 'occ:$series:$day';

  bool coversRepeatDate(String day) =>
      isRepeatRule &&
      day.compareTo(scheduledDate) >= 0 &&
      (repeatUntil == null || day.compareTo(repeatUntil!) < 0);

  bool repeatsOn(String day) =>
      coversRepeatDate(day) &&
      repeatWeekdays.contains(DateTime.parse(day).weekday);

  Task occurrenceOn(String day) => Task(
    id: occurrenceId(recurrenceId, day),
    seriesId: recurrenceId,
    title: title,
    scheduledDate: day,
    scheduledTime: scheduledTime,
    notes: notes,
    createdAt: createdAt,
    isDone: false,
    repeatWeekdays: repeatWeekdays,
    isProjected: true,
  );

  DateTime get date => DateTime.parse(scheduledDate);

  int? get hour {
    final value = scheduledTime;
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value.split(':').first);
  }

  int? get minute {
    final value = scheduledTime;
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]);
  }

  DateTime? get scheduledDateTime {
    final h = hour;
    if (h == null) return null;
    final d = date;
    return DateTime(d.year, d.month, d.day, h, minute ?? 0);
  }

  Task copyWith({
    String? title,
    String? scheduledDate,
    String? scheduledTime,
    bool clearTime = false,
    String? notes,
    bool clearNotes = false,
    bool? isDone,
    List<int>? repeatWeekdays,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: clearTime ? null : (scheduledTime ?? this.scheduledTime),
      notes: clearNotes ? null : (notes ?? this.notes),
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      seriesId: seriesId,
      repeatUntil: repeatUntil,
      isSkipped: isSkipped,
      isProjected: isProjected,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'scheduled_date': scheduledDate,
    'scheduled_time': scheduledTime,
    'notes': notes,
    'is_done': isDone ? 1 : 0,
    'created_at': createdAt,
    if (isRecurring) 'repeat_weekdays': repeatWeekdays.join(','),
    if (seriesId != null) 'series_id': seriesId,
    if (repeatUntil != null) 'repeat_until': repeatUntil,
    if (isSkipped) 'is_skipped': isProjected ? 2 : 1,
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id'] as String,
    title: map['title'] as String,
    scheduledDate: map['scheduled_date'] as String,
    scheduledTime: map['scheduled_time'] as String?,
    notes: map['notes'] as String?,
    isDone: (map['is_done'] as int? ?? 0) == 1,
    createdAt: map['created_at'] as int? ?? 0,
    repeatWeekdays: (map['repeat_weekdays'] as String? ?? '')
        .split(',')
        .where((day) => day.isNotEmpty)
        .map(int.parse)
        .toList(growable: false),
    seriesId: map['series_id'] as String?,
    repeatUntil: map['repeat_until'] as String?,
    isSkipped: map['is_skipped'] == 1 || map['is_skipped'] == 2,
    isProjected: map['is_skipped'] == 2,
  );

  Map<String, Object?> toWidgetJson() => {
    'id': id,
    'title': title,
    'time': scheduledTime ?? '',
    'done': isDone,
  };
}
