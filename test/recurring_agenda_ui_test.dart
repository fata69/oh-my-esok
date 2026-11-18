import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/data/task_dao.dart';
import 'package:jadwal/ui/task_editor.dart';
import 'package:jadwal/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  for (final (option, start, title, time, summary, weekdays, dates) in [
    (
      'Senin–Jumat',
      DateTime(2026, 11, 16),
      'Absen',
      '08:00',
      'Senin–Jumat · 08.00',
      [1, 2, 3, 4, 5],
      [16, 17, 18, 19, 20, 23, 24, 25],
    ),
    (
      'Setiap minggu',
      DateTime(2026, 11, 18),
      'Rapat QA',
      null,
      'Setiap minggu pada Rabu',
      [DateTime.wednesday],
      [18, 25],
    ),
  ]) {
    testWidgets('agenda editor saves $option and expands its dates', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 892);
      addTearDown(tester.view.reset);
      TaskEditorResult? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: EsokTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<TaskEditorResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TaskEditorSheet(initialDate: start),
                  );
                },
                child: const Text('Tambah tugas'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tambah tugas'));
      await tester.pumpAndSettle();
      final titleField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Apa yang perlu dikerjakan?',
      );
      await tester.enterText(
        titleField,
        time == null ? title : '$title jam $time',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ulangi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text(summary).hitTestable(), findsOneWidget);
      if (time == null) expect(find.textContaining('00.00'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Terapkan'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditorSheet), findsNothing);
      expect(result?.task, isNotNull);
      final saved = result!.task!;
      expect(saved.title, title);
      expect(saved.isRecurring, isTrue);
      expect(saved.repeatWeekdays, weekdays);
      expect(saved.scheduledDate, dateKey(start));
      expect(saved.scheduledTime, time);

      final occurrences = TaskDao.expandTasks(
        [saved],
        '2026-11-15',
        '2026-11-25',
      );
      expect(occurrences.map((task) => task.date.day), dates);
      expect(occurrences.map((task) => task.scheduledTime), everyElement(time));
    });
  }
}
