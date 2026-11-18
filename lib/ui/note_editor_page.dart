import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../data/day_note.dart';
import '../data/task.dart';
import '../util/format.dart';
import 'motion.dart';
import 'theme.dart';
import 'time_picker_sheet.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({
    super.key,
    this.note,
    required this.onSave,
    this.onDelete,
  });

  final DayNote? note;
  final Future<void> Function(DayNote note, DateTime? date, String? time)
  onSave;
  final Future<void> Function()? onDelete;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late final _id = widget.note?.id ?? const Uuid().v4();
  late final _createdAt =
      widget.note?.createdAt ?? DateTime.now().millisecondsSinceEpoch;
  (DateTime, String?)? _schedule;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    FocusScope.of(context).unfocus();
    final schedule =
        await showModalBottomSheet<({DateTime? date, String? time})>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          sheetAnimationStyle: EsokMotion.presentation(context),
          builder: (_) => _NoteScheduleSheet(schedule: _schedule),
        );
    if (!mounted || schedule == null) return;
    final date = schedule.date;
    setState(() => _schedule = date == null ? null : (date, schedule.time));
  }

  Future<void> _finish(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error, stack) {
      debugPrint('Note change failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perubahan belum bisa disimpan. Coba lagi.'),
        ),
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) return;
    final note = DayNote(
      id: _id,
      title: title,
      body: body,
      createdAt: _createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _finish(() => widget.onSave(note, _schedule?.$1, _schedule?.$2));
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _finish(onDelete);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final typography = Theme.of(context).textTheme;
    final schedule = _schedule;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.canvas,
          title: Text(widget.note == null ? 'Catatan baru' : 'Edit catatan'),
          actions: [
            if (widget.onDelete != null)
              IconButton(
                tooltip: 'Hapus catatan',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _busy ? null : _delete,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      TextField(
                        controller: _title,
                        readOnly: _busy,
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        style: typography.titleLarge,
                        decoration: const InputDecoration(
                          hintText: 'Judul',
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                      TextField(
                        controller: _body,
                        readOnly: _busy,
                        minLines: 6,
                        maxLines: null,
                        maxLength: 10000,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: typography.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: 'Tulis catatan…',
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _pickSchedule,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(
                          schedule == null
                              ? 'Jadwalkan'
                              : '${dateTitle(schedule.$1)}'
                                    '${schedule.$2 == null ? '' : ' · ${timeText(schedule.$2)}'}',
                        ),
                      ),
                      ListenableBuilder(
                        listenable: Listenable.merge([_title, _body]),
                        builder: (context, _) => FilledButton(
                          onPressed:
                              _busy ||
                                  (_title.text.trim().isEmpty &&
                                      _body.text.trim().isEmpty)
                              ? null
                              : _save,
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
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

class _NoteScheduleSheet extends StatefulWidget {
  const _NoteScheduleSheet({required this.schedule});

  final (DateTime, String?)? schedule;

  @override
  State<_NoteScheduleSheet> createState() => _NoteScheduleSheetState();
}

class _NoteScheduleSheetState extends State<_NoteScheduleSheet> {
  late var _date = widget.schedule?.$1 ?? today();
  late var _time = widget.schedule?.$2;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today(),
      lastDate: today().add(const Duration(days: 3650)),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (date != null && mounted) setState(() => _date = dateOnly(date));
  }

  Future<void> _pickTime() async {
    final current = _time;
    final parsed = current?.split(':');
    final time = await showTimePickerSheet(
      context,
      initial: parsed == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(
              hour: int.parse(parsed.first),
              minute: int.parse(parsed.last),
            ),
    );
    if (time != null && mounted) {
      setState(() {
        _time =
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Material(
      color: colors.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Jadwalkan catatan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text('${weekdayName(_date)}, ${dateTitle(_date)}'),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(_time == null ? 'Tambah jam' : timeText(_time)),
                onTap: _pickTime,
                trailing: _time == null
                    ? null
                    : IconButton(
                        tooltip: 'Hapus jam',
                        onPressed: () => setState(() => _time = null),
                        icon: const Icon(Icons.close),
                      ),
              ),
              const SizedBox(height: 8),
              const Text('Catatan masuk ke Agenda setelah disimpan.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop((date: _date, time: _time)),
                child: const Text('Pakai jadwal'),
              ),
              if (widget.schedule != null)
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pop((date: null as DateTime?, time: null as String?)),
                  child: const Text('Hapus jadwal'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
