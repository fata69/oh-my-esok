import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/backup/auto_backup.dart';
import 'package:jadwal/backup/backup_recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const backupChannel = MethodChannel('esok/settings');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(backupChannel, null);
    AutoBackup.recovery.startFresh();
  });

  test(
    'pausing or forcing a backup cannot overwrite pending recovery',
    () async {
      final recovery = AutoBackup.recovery;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(backupChannel, (call) async {
        methods.add(call.method);
        return null;
      });
      recovery.awaitDecision();
      expect(await AutoBackup.runIfChanged(), isFalse);
      expect(await AutoBackup.runIfChanged(force: true), isFalse);
      expect(AutoBackup.lastError, contains('ditunda'));

      final pendingWrite = Completer<void>();
      final result = recovery.restore(
        replace: () => pendingWrite.future,
        refreshStores: () async {},
        rescheduleReminders: () async {},
        syncWidgets: () async {},
      );
      expect(recovery.phase, RecoveryPhase.restoring);
      expect(await AutoBackup.runIfChanged(), isFalse);
      expect(methods, isEmpty);
      pendingWrite.complete();
      await result;
      expect(recovery.blocksBackup, isFalse);
    },
  );

  test(
    'failed replace leaves source protected and lets recovery retry',
    () async {
      final recovery = BackupRecovery()..awaitDecision();
      final sideEffects = <String>[];
      await expectLater(
        recovery.restore(
          replace: () async => throw StateError('synthetic write failure'),
          refreshStores: () async => sideEffects.add('stores'),
          rescheduleReminders: () async => sideEffects.add('reminders'),
          syncWidgets: () async => sideEffects.add('widgets'),
        ),
        throwsStateError,
      );
      expect(recovery.phase, RecoveryPhase.awaitingDecision);
      expect(recovery.blocksBackup, isTrue);
      expect(sideEffects, isEmpty);
      recovery.startFresh();
      expect(recovery.blocksBackup, isFalse);
    },
  );

  test(
    'restore commit precedes alarms; alarm failure still syncs widgets',
    () async {
      final recovery = BackupRecovery()..awaitDecision();
      final calls = <String>[];
      final alarms = Completer<void>();
      final result = recovery.restore(
        replace: () async => calls.add('sqlite'),
        refreshStores: () async => calls.add('stores'),
        rescheduleReminders: () async {
          calls.add('reminders');
          await alarms.future;
        },
        syncWidgets: () async => calls.add('widgets'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['sqlite', 'stores', 'reminders']);
      expect(recovery.blocksBackup, isTrue);
      alarms.completeError(StateError('exact and inexact alarms failed'));
      expect(await result, [RecoveryWarning.reminders]);
      expect(calls, ['sqlite', 'stores', 'reminders', 'widgets']);
      expect(recovery.phase, RecoveryPhase.ready);
    },
  );

  test(
    'startup distinguishes a missing backup from unreadable content',
    () async {
      var modified = false;
      String? contents;
      messenger.setMockMethodCallHandler(backupChannel, (call) async {
        return switch (call.method) {
          'readBackup' => contents,
          'backupModifiedAt' => modified ? 123 : null,
          _ => throw StateError('Unexpected backup method'),
        };
      });

      expect((await AutoBackup.readForRecovery()).unreadable, isFalse);
      modified = true;
      expect((await AutoBackup.readForRecovery()).unreadable, isTrue);
      contents = '';
      expect((await AutoBackup.readForRecovery()).unreadable, isTrue);
      contents = '{"app":"esok","schemaVersion":5}';
      expect((await AutoBackup.readForRecovery()).unreadable, isTrue);
      contents =
          '{"app":"esok","schemaVersion":5,"tasks":[],"transactions":[],'
          '"accounts":[],"categories":[]}';
      final validEmpty = await AutoBackup.readForRecovery();
      expect(validEmpty.data, isNull);
      expect(validEmpty.unreadable, isFalse);
    },
  );
}
