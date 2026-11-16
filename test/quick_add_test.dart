import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/data/task.dart';
import 'package:jadwal/parse/quick_add.dart';

void main() {
  final now = DateTime(2026, 11, 13, 9);

  group('parseQuickAdd', () {
    test('besok dengan jam sore', () {
      final result = parseQuickAdd('beli telur besok jam 4 sore', now: now);
      expect(result.title, 'Beli telur');
      expect(result.date, DateTime(2026, 11, 14));
      expect(result.time, '16:00');
      expect(result.dateFound, isTrue);
      expect(result.timeFound, isTrue);
    });

    test('N hari lagi tanpa jam', () {
      final result = parseQuickAdd('bayar listrik 3 hari lagi', now: now);
      expect(result.title, 'Bayar listrik');
      expect(result.date, DateTime(2026, 11, 16));
      expect(result.time, isNull);
    });

    test('lusa dengan jam 24-an', () {
      final result = parseQuickAdd('rapat lusa jam 09:00', now: now);
      expect(result.title, 'Rapat');
      expect(result.date, DateTime(2026, 11, 15));
      expect(result.time, '09:00');
    });

    test('tanpa penanda tanggal', () {
      final result = parseQuickAdd('olahraga', now: now);
      expect(result.title, 'Olahraga');
      expect(result.date, DateTime(2026, 11, 13));
      expect(result.time, isNull);
      expect(result.dateFound, isFalse);
    });

    test('jam 12 malam jadi tengah malam', () {
      final result = parseQuickAdd('jaga pos jam 12 malam', now: now);
      expect(result.title, 'Jaga pos');
      expect(result.time, '00:00');
    });

    test('jam 1 siang jadi 13.00', () {
      final result = parseQuickAdd('makan siang jam 1 siang', now: now);
      expect(result.title, 'Makan siang');
      expect(result.time, '13:00');
    });

    test('hari lampau', () {
      final result = parseQuickAdd('cuci motor kemarin', now: now);
      expect(result.title, 'Cuci motor');
      expect(result.date, DateTime(2026, 11, 12));
    });
  });

  test('dateKey selalu dua digit', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('Task bolak-balik lewat map', () {
    final task = Task(
      id: 'abc',
      title: 'Bayar listrik',
      scheduledDate: '2026-11-13',
      scheduledTime: '19:30',
      notes: 'token',
      isDone: false,
      createdAt: 1,
    );
    final restored = Task.fromMap(task.toMap());
    expect(restored.title, task.title);
    expect(restored.scheduledDateTime, DateTime(2026, 11, 13, 19, 30));
    expect(restored.isDone, isFalse);
  });
}
