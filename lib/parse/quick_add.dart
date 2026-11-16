import '../data/task.dart';

class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.date,
    this.time,
    this.dateFound = false,
    this.timeFound = false,
  });

  final String title;
  final DateTime date;
  final String? time;
  final bool dateFound;
  final bool timeFound;
}

final _dateWord = RegExp(
  r'\b(hari ini|besok|lusa|kemarin)\b',
  caseSensitive: false,
);

final _relativeDays = RegExp(
  r'\b(\d{1,3})\s*hari\s*(lagi|lalu|kemudian)?\b',
  caseSensitive: false,
);

final _time = RegExp(
  r'\b(?:jam|pukul)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(pagi|siang|sore|malam|subuh)?\b',
  caseSensitive: false,
);

String _two(int value) => value.toString().padLeft(2, '0');

String _removeRange(String input, int start, int end) {
  final result = '${input.substring(0, start)} ${input.substring(end)}';
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String stripDatePhrase(String input) {
  final word = _dateWord.firstMatch(input);
  if (word != null) return _removeRange(input, word.start, word.end);
  final relative = _relativeDays.firstMatch(input);
  if (relative != null) {
    return _removeRange(input, relative.start, relative.end);
  }
  return input;
}

String stripTimePhrase(String input) {
  final match = _time.firstMatch(input);
  if (match == null) return input;
  return _removeRange(input, match.start, match.end);
}

QuickAddResult parseQuickAdd(String input, {DateTime? now}) {
  final base = dateOnly(now ?? DateTime.now());
  var date = base;
  String? time;
  var dateFound = false;
  var timeFound = false;
  final cuts = <List<int>>[];

  final dateWord = _dateWord.firstMatch(input);
  if (dateWord != null) {
    dateFound = true;
    switch (dateWord.group(1)!.toLowerCase()) {
      case 'hari ini':
        date = base;
      case 'besok':
        date = base.add(const Duration(days: 1));
      case 'lusa':
        date = base.add(const Duration(days: 2));
      case 'kemarin':
        date = base.subtract(const Duration(days: 1));
    }
    cuts.add([dateWord.start, dateWord.end]);
  } else {
    final relative = _relativeDays.firstMatch(input);
    if (relative != null) {
      dateFound = true;
      final amount = int.tryParse(relative.group(1)!) ?? 0;
      final direction = (relative.group(2) ?? 'lagi').toLowerCase();
      date = direction == 'lalu'
          ? base.subtract(Duration(days: amount))
          : base.add(Duration(days: amount));
      cuts.add([relative.start, relative.end]);
    }
  }

  final timeMatch = _time.firstMatch(input);
  if (timeMatch != null) {
    var hour = int.tryParse(timeMatch.group(1)!) ?? 0;
    final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
    final period = timeMatch.group(3)?.toLowerCase();

    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      switch (period) {
        case 'siang':
        case 'sore':
          if (hour < 12) hour += 12;
        case 'malam':
          if (hour == 12) {
            hour = 0;
          } else if (hour < 12) {
            hour += 12;
          }
        case 'subuh':
        case 'pagi':
          if (hour == 12) hour = 0;
      }
      if (hour > 23) hour = hour % 24;
      time = '${_two(hour)}:${_two(minute)}';
      timeFound = true;
      cuts.add([timeMatch.start, timeMatch.end]);
    }
  }

  var title = input;
  cuts.sort((a, b) => b[0].compareTo(a[0]));
  for (final cut in cuts) {
    title = '${title.substring(0, cut[0])} ${title.substring(cut[1])}';
  }
  title = title
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,\-–—]+'), '')
      .replaceAll(RegExp(r'[\s,\-–—]+$'), '')
      .trim();
  if (title.isNotEmpty) {
    title = title[0].toUpperCase() + title.substring(1);
  }

  return QuickAddResult(
    title: title,
    date: date,
    time: time,
    dateFound: dateFound,
    timeFound: timeFound,
  );
}
