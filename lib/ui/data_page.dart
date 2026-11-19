import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../backup/auto_backup.dart';
import '../backup/backup_service.dart';
import '../data/database.dart';
import '../data/money_transaction_dao.dart';
import '../data/task_dao.dart';
import '../notify/notifier.dart';
import '../state/money_store.dart';
import '../state/task_store.dart';
import '../widget/widget_sync.dart';
import 'chevron.dart';
import 'motion.dart';
import 'theme.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  int? _taskCount;
  int? _transactionCount;
  int? _sizeBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = await AppDatabase.open();
    final counts = await Future.wait<int>([
      TaskDao(db).countAll(),
      MoneyTransactionDao(db).countAll(),
    ]);
    final directory = await getDatabasesPath();
    final file = File(p.join(directory, 'esok.db'));
    var size = 0;
    if (await file.exists()) size = await file.length();
    if (!mounted) return;
    setState(() {
      _taskCount = counts[0];
      _transactionCount = counts[1];
      _sizeBytes = size;
    });
  }

  String get _sizeLabel {
    final bytes = _sizeBytes;
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _export() async {
    final data = await BackupService.collect();
    if (!mounted) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (_) => _ExportSheet(data: data),
    );
    if (message != null) _message(message);
  }

  Future<void> _import() async {
    if (_busy) return;
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Pilih cadangan Esok',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final data = await BackupService.parseJsonBytes(bytes);
      if (!mounted) return;
      if (data.isEmpty) {
        _message('Cadangan kosong. Data saat ini tidak diubah.');
        return;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        sheetAnimationStyle: EsokMotion.presentation(context),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: EsokColors.scrim,
        builder: (_) => _ImportSheet(fileName: picked.name, data: data),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      final taskStore = context.read<TaskStore>();
      final moneyStore = context.read<MoneyStore>();
      await BackupService.replaceAll(data);
      await WidgetSync.drainPendingToggles(taskStore);
      await AutoBackup.runIfChanged(force: true);
      if (!mounted) return;
      await taskStore.refresh();
      await taskStore.loadMonth(taskStore.selectedDate);
      await moneyStore.refresh();
      await TaskNotifier.instance.syncFromDatabase();
      await WidgetSync.push();
      await _loadStats();
      if (!mounted) return;
      setState(() => _busy = false);
      _message(
        '${data.tasks.length} agenda, ${data.notes.length} catatan, '
        '${data.transactions.length} transaksi dimuat.',
      );
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('Impor gagal: $error');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: EsokMotion.presentation(context),
      builder: (context) => AlertDialog(
        backgroundColor: EsokColors.of(context).canvas,
        title: const Text('Hapus semua data?'),
        content: const Text(
          'Seluruh agenda, catatan, dan data uang akan dihapus. '
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await BackupService.clearAll();
      await AutoBackup.runIfChanged(force: true);
      await TaskNotifier.instance.cancelAll();
      await WidgetSync.push();
      if (!mounted) return;
      final taskStore = context.read<TaskStore>();
      final moneyStore = context.read<MoneyStore>();
      await taskStore.refresh();
      await moneyStore.refresh();
      await _loadStats();
      if (mounted) _message('Semua data sudah dihapus.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(child: EsokChevron(left: true)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Data',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _StatsRow(
                    tasks: _taskCount,
                    transactions: _transactionCount,
                    size: _sizeLabel,
                  ),
                  const _SectionLabel('Cadangan'),
                  _DataRow(
                    icon: Icons.file_upload_outlined,
                    label: 'Ekspor semua data',
                    detail: 'JSON lengkap atau CSV',
                    trailing: '›',
                    onTap: _busy ? null : _export,
                  ),
                  _DataRow(
                    icon: Icons.file_download_outlined,
                    label: 'Impor dari berkas',
                    detail: 'Menggantikan data yang ada',
                    trailing: '›',
                    onTap: _busy ? null : _import,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _InfoBox(),
                  ),
                  const _SectionLabel('Cadangan otomatis'),
                  const _DataRow(
                    icon: Icons.cloud_off_outlined,
                    label: 'Cadangan Android',
                    detail: 'Nonaktif — kamu yang mengatur',
                    trailing: 'OFF',
                  ),
                  const _SectionLabel('Berbahaya'),
                  _DataRow(
                    icon: Icons.delete_outline,
                    label: 'Hapus semua data',
                    danger: true,
                    trailing: '›',
                    onTap: _busy ? null : _clearAll,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.tasks,
    required this.transactions,
    required this.size,
  });

  final int? tasks;
  final int? transactions;
  final String size;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StatCell(label: 'TUGAS', value: tasks?.toString() ?? '—'),
          _StatCell(label: 'TRANSAKSI', value: transactions?.toString() ?? '—'),
          _StatCell(label: 'UKURAN', value: size, last: true),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : Border(right: BorderSide(color: colors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.06,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.09,
          color: colors.muted,
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    this.detail,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Icon(
                icon,
                size: 19,
                color: danger ? colors.lateInk : colors.ink,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: danger ? colors.lateInk : colors.ink,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(fontSize: 11.5, color: colors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 11.5, height: 1.7, color: colors.muted),
          children: [
            TextSpan(text: 'Berkas cadangan berisi '),
            TextSpan(
              text: 'agenda, catatan, transaksi, kategori, dompet, dan Sampai Gajian',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.inkSoft,
              ),
            ),
            TextSpan(
              text: '. Simpan di Google Drive, SD card, atau kirim ke diri sendiri.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.data});

  final BackupData data;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String _format = 'json';
  bool _busy = false;

  Future<File> _file() {
    return _format == 'csv'
        ? BackupService.createCsvFile(widget.data)
        : BackupService.createJsonFile(widget.data);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _file();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: _format == 'csv' ? 'Transaksi Esok' : 'Cadangan Esok',
        ),
      );
      if (mounted) Navigator.of(context).pop('Berkas siap dibagikan.');
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ekspor gagal: $error')));
      }
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _file();
      final uri = await FilePicker.saveFile(
        fileName: p.basename(file.path),
        bytes: await file.readAsBytes(),
        mimeType: _format == 'csv' ? 'text/csv' : 'application/json',
        dialogTitle: _format == 'csv'
            ? 'Simpan transaksi CSV'
            : 'Simpan cadangan Esok',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (uri != null) {
        Navigator.of(context)
            .pop(_format == 'csv' ? 'CSV disimpan.' : 'Cadangan disimpan.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final csv = _format == 'csv';
    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: EsokColors.sheetRadius,
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Ekspor data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              csv
                  ? '${widget.data.transactions.length} transaksi'
                  : '${widget.data.tasks.length} agenda · '
                        '${widget.data.notes.length} catatan · '
                        '${widget.data.transactions.length} transaksi · '
                        '${widget.data.categories.length} kategori · '
                        '${widget.data.accounts.length} dompet',
              style: TextStyle(fontSize: 11.5, color: colors.muted),
            ),
            const SizedBox(height: 18),
            Text(
              'FORMAT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.09,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _FormatChip(
                  label: 'JSON',
                  detail: 'lengkap',
                  selected: _format == 'json',
                  onTap: () => setState(() => _format = 'json'),
                ),
                const SizedBox(width: 8),
                _FormatChip(
                  label: 'CSV',
                  detail: 'untuk Excel',
                  selected: _format == 'csv',
                  onTap: () => setState(() => _format = 'csv'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.lateSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                csv
                    ? 'CSV berisi tabel transaksi untuk Excel. Untuk memulihkan data di Oh My Esok, pilih cadangan JSON.'
                    : 'JSON adalah cadangan lengkap yang bisa diimpor kembali ke Oh My Esok. Simpan di folder pribadi.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.65,
                  color: colors.lateInk,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.fabText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Bagikan berkas'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: _busy ? null : _save,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.lineStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Simpan ke penyimpanan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? colors.ink : colors.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? colors.canvas : colors.inkSoft,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              detail,
              style: TextStyle(
                fontSize: 9.5,
                color: selected
                    ? colors.canvas.withValues(alpha: 0.65)
                    : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportSheet extends StatelessWidget {
  const _ImportSheet({required this.fileName, required this.data});

  final String fileName;
  final BackupData data;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: EsokColors.sheetRadius,
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Periksa sebelum impor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Berkas dibaca, belum ada yang diubah.',
                style: TextStyle(fontSize: 11.5, color: colors.muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.tasks.length} agenda · '
                      '${data.notes.length} catatan · '
                      '${data.transactions.length} transaksi · '
                      '${data.categories.length} kategori · '
                      '${data.accounts.length} dompet'
                      '${data.paydayPlan.isEmpty ? '' : ' · Sampai Gajian'}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.55,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.lateSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Data sekarang akan diganti seluruhnya. Setelah impor, '
                  'notifikasi dijadwalkan ulang dan widget diperbarui.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.65,
                    color: colors.lateInk,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.fabText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text('Ganti dengan cadangan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
