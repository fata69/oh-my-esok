import 'package:material_ui/material_ui.dart';

import '../data/task.dart';
import '../state/day_review.dart';
import '../util/format.dart';

Future<void> showDayReviewSheet(
  BuildContext context, {
  required DateTime date,
  required DayReviewService service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DayReviewSheet(date: dateOnly(date), service: service),
  );
}

class DayReviewSheet extends StatefulWidget {
  const DayReviewSheet({super.key, required this.date, required this.service});

  final DateTime date;
  final DayReviewService service;

  @override
  State<DayReviewSheet> createState() => _DayReviewSheetState();
}

class _DayReviewSheetState extends State<DayReviewSheet>
    with WidgetsBindingObserver {
  late Future<DayReview> _future;
  bool _busy = false;
  bool _prompting = false;
  bool _reloadOnReturn = false;
  String? _notice;
  String? _pendingSyncId;
  Set<DayReviewIssue> _issues = const {};

  bool get _locked => _busy || _prompting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = widget.service.load(widget.date);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_locked) {
      _reloadOnReturn = true;
    } else {
      _reload();
    }
  }

  void _reload() {
    final next = widget.service.load(widget.date);
    setState(() {
      _future = next;
    });
  }

  void _finishAction() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _prompting = false;
      if (_reloadOnReturn) {
        _reloadOnReturn = false;
        _future = widget.service.load(widget.date);
      }
    });
  }

  String _dateLabel(DateTime date) => '${dateTitle(date)} ${date.year}';

  Future<void> _reschedule(Task task) async {
    if (_locked || _pendingSyncId != null) return;
    setState(() => _prompting = true);
    try {
      final now = today();
      final later = task.date.isAfter(now) ? task.date : now;
      final initial = DateTime(later.year, later.month, later.day + 1);
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: now,
        lastDate: DateTime(
          initial.year > now.year + 10 ? initial.year : now.year + 10,
          12,
          31,
        ),
        selectableDayPredicate: (day) => dateOnly(day) != task.date,
        helpText: 'Tanggal tujuan',
        cancelText: 'Batal',
        confirmText: 'Lanjut',
      );
      if (picked == null || !mounted) return;
      final time = task.scheduledTime;
      final preview = task.copyWith(scheduledDate: dateKey(picked));
      final reminderInPast =
          preview.scheduledDateTime?.isBefore(DateTime.now()) ?? false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pindahkan catatan?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title),
                const SizedBox(height: 16),
                Text('Dari ${_dateLabel(task.date)}'),
                const SizedBox(height: 4),
                Text('Ke ${_dateLabel(picked)}'),
                const SizedBox(height: 12),
                Text(
                  time == null
                      ? 'Tanpa jam. Tidak ada pengingat.'
                      : reminderInPast
                      ? 'Jam ${timeText(time)} tetap. Waktunya sudah lewat; '
                            'pengingat tidak dijadwalkan.'
                      : 'Jam ${timeText(time)} tetap.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Pindahkan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      final result = await widget.service.reschedule(
        id: task.id,
        from: task.date,
        to: picked,
      );
      if (!mounted) return;
      setState(() {
        _issues = result.issues;
        _pendingSyncId = result.moved && _issues.isNotEmpty ? task.id : null;
        _notice = result.moved
            ? 'Dipindahkan ke ${_dateLabel(picked)}.'
            : 'Catatan sudah berubah. Tidak dipindahkan.';
        _future = widget.service.load(widget.date);
      });
    } catch (error, stack) {
      debugPrint('Day review move failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _notice = 'Belum dipindahkan. Coba lagi.');
    } finally {
      _finishAction();
    }
  }

  Future<void> _retrySync() async {
    final id = _pendingSyncId;
    if (_locked || id == null) return;
    setState(() => _busy = true);
    try {
      final issues = await widget.service.synchronize(id);
      if (!mounted) return;
      setState(() {
        _issues = issues;
        _pendingSyncId = issues.isEmpty ? null : id;
        _notice = issues.isEmpty
            ? 'Pembaruan selesai.'
            : 'Tanggal sudah tersimpan.';
        _future = widget.service.load(widget.date);
      });
    } finally {
      _finishAction();
    }
  }

  Widget _buildReview(DayReview review) {
    final incomplete = review.incompleteTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Arus kas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _MoneyLine(label: 'Masuk', amount: review.income, income: true),
        const SizedBox(height: 8),
        _MoneyLine(label: 'Keluar', amount: review.expense, income: false),
        if (!review.transactions.any(
          (entry) => entry.isIncome || entry.isExpense,
        ))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Belum ada pemasukan atau pengeluaran.'),
          ),
        const SizedBox(height: 24),
        Text(
          'Belum selesai (${incomplete.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (incomplete.isEmpty)
          Text(
            review.tasks.isEmpty
                ? 'Belum ada catatan di tanggal ini.'
                : 'Semua catatan sudah selesai.',
          ),
        for (final task in incomplete) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: Theme.of(context).textTheme.bodyLarge),
                if (task.scheduledTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Pukul ${timeText(task.scheduledTime)}'),
                  ),
                TextButton.icon(
                  onPressed: _locked || _pendingSyncId != null
                      ? null
                      : () => _reschedule(task),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: const Text('Jadwalkan ulang'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 16),
        const Text('Pindahkan satu per satu, atau selesai tanpa perubahan.'),
      ],
    );
  }

  Widget _buildNotice() {
    final color = Theme.of(context).colorScheme;
    final messages = [
      ?_notice,
      if (_issues.contains(DayReviewIssue.reminder))
        'Pengingat belum diperbarui.',
      if (_issues.contains(DayReviewIssue.widget)) 'Widget belum diperbarui.',
      if (_issues.contains(DayReviewIssue.refresh))
        'Daftar belum dimuat ulang.',
    ];
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(messages.join(' ')),
            if (_pendingSyncId != null)
              TextButton(
                onPressed: _locked ? null : _retrySync,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Coba sinkronkan lagi'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_locked,
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tutup hari',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(_dateLabel(widget.date)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _locked
                            ? null
                            : () => Navigator.of(context).pop(),
                        tooltip: 'Tutup',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    children: [
                      if (_notice != null || _issues.isNotEmpty) _buildNotice(),
                      FutureBuilder<DayReview>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  semanticsLabel: 'Memuat ringkasan',
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Ringkasan belum bisa dimuat.'),
                                TextButton(
                                  onPressed: _locked ? null : _reload,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: const Text('Coba lagi'),
                                ),
                              ],
                            );
                          }
                          return _buildReview(snapshot.requireData);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: FilledButton(
                    onPressed: _locked
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.amount,
    required this.income,
  });

  final String label;
  final int amount;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final sign = amount == 0
        ? ''
        : income
        ? (amount < 0 ? '−' : '+')
        : (amount < 0 ? '+' : '−');
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label),
        Text(
          '$sign${rupiahText(amount.abs())}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
