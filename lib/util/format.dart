import 'package:intl/intl.dart';

import '../data/task.dart';

String timeText(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.replaceAll(':', '.');
}

String dateTitle(DateTime date) => DateFormat('d MMMM', 'id_ID').format(date);

String shortDateTitle(DateTime date) =>
    DateFormat('d MMM', 'id_ID').format(date);

String weekdayName(DateTime date) => DateFormat('EEEE', 'id_ID').format(date);

String shortDayDate(DateTime date) =>
    DateFormat('EEE d MMM', 'id_ID').format(date);

String monthTitle(DateTime date) =>
    DateFormat('MMMM yyyy', 'id_ID').format(date);

String positionLabel(DateTime date, {DateTime? now}) {
  final base = dateOnly(now ?? DateTime.now());
  final delta = daysBetween(base, date);
  if (delta == 0) return 'Hari ini';
  if (delta == 1) return 'Besok';
  if (delta == -1) return 'Kemarin';
  if (delta > 1) return '$delta hari lagi';
  return '${-delta} hari lalu';
}

String taskCountLabel(int count) {
  if (count == 0) return 'tidak ada tugas';
  return '$count tugas';
}

final _numberFormat = NumberFormat.decimalPattern('id_ID');

String numberText(int value) => _numberFormat.format(value);

String rupiahText(int value) => 'Rp ${_numberFormat.format(value)}';

String signedNumberText(int value) {
  final sign = value < 0 ? '−' : '';
  return '$sign${_numberFormat.format(value.abs())}';
}

String moneyDayLabel(DateTime date) {
  final day = dateOnly(date);
  if (day == today()) {
    return 'Hari ini · ${weekdayName(day)}, ${shortDateTitle(day)}';
  }
  if (day == today().subtract(const Duration(days: 1))) {
    return 'Kemarin · ${weekdayName(day)}, ${shortDateTitle(day)}';
  }
  return '${weekdayName(day)}, ${shortDateTitle(day)}';
}
