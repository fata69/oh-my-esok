import '../data/task.dart';
import '../util/format.dart';

/// Keep future slots for completed tasks, so undo in the widget can rearm them
/// without opening Flutter. Android decides whether the occurrence is eligible.
List<Map<String, Object?>> agendaReminderAlarms(
  Task task, {
  required DateTime now,
  required DateTime? when,
  required String channel,
  required String sound,
  required int? leadMinutes,
}) {
  if (when == null || !when.isAfter(now)) return const [];
  final time = task.scheduledTime!;
  final common = {
    'taskId': task.id,
    'day': task.scheduledDate,
    'time': time,
    'title': task.title,
    'channel': channel,
    'sound': sound,
    'done': task.isDone,
  };
  final lead = leadMinutes == null
      ? null
      : when.subtract(Duration(minutes: leadMinutes));
  return [
    {
      ...common,
      'slot': 1,
      'when': when.millisecondsSinceEpoch,
      'body': 'Pengingat jam ${timeText(time)}',
    },
    if (lead != null && lead.isAfter(now))
      {
        ...common,
        'slot': 2,
        'when': lead.millisecondsSinceEpoch,
        'body': 'Pengingat awal · pukul ${timeText(time)}',
      },
  ];
}
