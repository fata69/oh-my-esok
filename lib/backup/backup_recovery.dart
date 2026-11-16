enum RecoveryPhase { ready, awaitingDecision, restoring }

enum RecoveryWarning { stores, reminders, widgets }

class BackupRecovery {
  RecoveryPhase _phase = RecoveryPhase.ready;

  RecoveryPhase get phase => _phase;
  bool get blocksBackup => _phase != RecoveryPhase.ready;

  void awaitDecision() {
    if (_phase != RecoveryPhase.restoring) {
      _phase = RecoveryPhase.awaitingDecision;
    }
  }

  void startFresh() {
    if (_phase == RecoveryPhase.restoring) {
      throw StateError('Recovery is still in progress.');
    }
    _phase = RecoveryPhase.ready;
  }

  Future<List<RecoveryWarning>> restore({
    required Future<void> Function() replace,
    required Future<void> Function() refreshStores,
    required Future<void> Function() rescheduleReminders,
    required Future<void> Function() syncWidgets,
  }) async {
    if (_phase != RecoveryPhase.awaitingDecision) {
      throw StateError('Recovery requires an explicit decision.');
    }
    _phase = RecoveryPhase.restoring;
    try {
      await replace();
    } catch (_) {
      // Preserve the source backup and let the user retry or start fresh.
      _phase = RecoveryPhase.awaitingDecision;
      rethrow;
    }

    final warnings = <RecoveryWarning>[];
    for (final step in <(RecoveryWarning, Future<void> Function())>[
      (RecoveryWarning.stores, refreshStores),
      (RecoveryWarning.reminders, rescheduleReminders),
      (RecoveryWarning.widgets, syncWidgets),
    ]) {
      try {
        await step.$2();
      } catch (_) {
        // SQLite has committed. An alarm failure must not undo the restore
        // or prevent independently attempting the widget refresh.
        warnings.add(step.$1);
      }
    }
    _phase = RecoveryPhase.ready;
    return warnings;
  }
}
