import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../data/task.dart';
import '../parse/quick_add.dart';
import '../util/format.dart';
import 'task_repeat.dart';
import 'theme.dart';
import 'time_picker_sheet.dart';

class TaskEditorResult {
  const TaskEditorResult.save(Task value)
    : task = value,
      deleted = false,
      removeSchedule = false;

  const TaskEditorResult.delete()
    : task = null,
      deleted = true,
      removeSchedule = false;

  const TaskEditorResult.unschedule(Task value)
    : task = value,
      deleted = false,
      removeSchedule = true;

  final Task? task;
  final bool deleted;
  final bool removeSchedule;
}

enum TaskEditScope { occurrence, following }

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.initialDate,
    this.task,
    this.scope,
  });

  final DateTime initialDate;
  final Task? task;
  final TaskEditScope? scope;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final FocusNode _notesFocus;
  late DateTime _date;
  String? _time;
  late TaskRepeatRule _repeat;
  bool get _dateLocked => widget.scope != null;
  bool get _canChangeRepeat => widget.scope != TaskEditScope.occurrence;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '')
      ..addListener(_onTitleChanged);
    _notesController = TextEditingController(text: widget.task?.notes ?? '');
    _notesFocus = FocusNode()..addListener(_onNotesFocusChanged);
    _date = widget.task?.date ?? dateOnly(widget.initialDate);
    _time = widget.task?.scheduledTime;
    _repeat = TaskRepeatRule.fromWeekdays(
      widget.task?.repeatWeekdays ?? [],
      _date,
    );
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    _notesController.dispose();
    _notesFocus
      ..removeListener(_onNotesFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  void _onNotesFocusChanged() {
    if (!_notesFocus.hasFocus) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || !_notesFocus.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Future<void> _pickDate() async {
    final parsed = parseQuickAdd(_titleController.text);
    if (parsed.dateFound) {
      _titleController.text = stripDatePhrase(_titleController.text);
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
      _date = parsed.date;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today().subtract(const Duration(days: 3650)),
      lastDate: today().add(const Duration(days: 3650)),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _pickTime() async {
    final parsed = parseQuickAdd(_titleController.text);
    if (parsed.timeFound) {
      _titleController.text = stripTimePhrase(_titleController.text);
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
      _time = parsed.time;
    }
    final initial = _time == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(
            hour: int.tryParse(_time!.split(':').first) ?? 9,
            minute: int.tryParse(_time!.split(':').last) ?? 0,
          );
    final picked = await showTimePickerSheet(context, initial: initial);
    if (picked != null && mounted) {
      final value =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _time = value);
    }
  }

  Future<void> _pickRepeat(DateTime date, String? time) async {
    FocusScope.of(context).unfocus();
    final picked = await showTaskRepeatPicker(
      context,
      current: _repeat,
      date: date,
      time: time,
    );
    if (picked != null && mounted) setState(() => _repeat = picked);
  }

  void _save() {
    final raw = _titleController.text.trim();
    if (raw.isEmpty) return;

    final parsed = parseQuickAdd(raw);
    final titleDraft = _dateLocked && parsed.dateFound
        ? parsed.timeFound
              ? stripTimePhrase(raw).trim()
              : raw
        : parsed.title;
    final title = titleDraft.isEmpty ? raw : titleDraft;
    final finalDate = !_dateLocked && parsed.dateFound ? parsed.date : _date;
    final finalTime = parsed.timeFound ? parsed.time : _time;
    final notes = _notesController.text.trim();
    final repeatWeekdays = _canChangeRepeat
        ? _repeat.weekdaysFor(finalDate)
        : widget.task!.repeatWeekdays;
    final original = widget.task;
    final task = original == null
        ? Task(
            id: const Uuid().v4(),
            title: title,
            scheduledDate: dateKey(finalDate),
            scheduledTime: finalTime,
            notes: notes.isEmpty ? null : notes,
            isDone: false,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            repeatWeekdays: repeatWeekdays,
          )
        : original.copyWith(
            title: title,
            scheduledDate: dateKey(finalDate),
            scheduledTime: finalTime,
            clearTime: finalTime == null,
            notes: notes,
            clearNotes: notes.isEmpty,
            repeatWeekdays: repeatWeekdays,
          );

    Navigator.of(context).pop(TaskEditorResult.save(task));
  }

  Future<void> _removeSchedule() async {
    final task = widget.task;
    final title = _titleController.text.trim();
    final body = _notesController.text.trim();
    if (task == null || task.isRecurring || (title.isEmpty && body.isEmpty)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pindahkan ke Catatan?'),
        content: const Text('Tanggal dan pengingat agenda akan dilepas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pindahkan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    Navigator.of(context).pop(
      TaskEditorResult.unschedule(
        task.copyWith(title: title, notes: body, clearNotes: body.isEmpty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final typography = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final parsed = parseQuickAdd(_titleController.text);
    final canSave = _titleController.text.trim().isNotEmpty;
    final isEditing = widget.task != null;
    final effectiveDate = !_dateLocked && parsed.dateFound
        ? parsed.date
        : _date;
    final effectiveTime = parsed.timeFound ? parsed.time : _time;

    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Ubah tugas' : 'Tugas baru',
                    style: typography.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.control,
                    foregroundColor: colors.ink,
                    minimumSize: const Size.square(48),
                    visualDensity: VisualDensity.standard,
                  ),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.scope != null) ...[
              Text(
                switch (widget.scope!) {
                  TaskEditScope.occurrence =>
                    'Hanya kali ini · ${weekdayName(_date)}, ${dateTitle(_date)}',
                  TaskEditScope.following =>
                    'Mulai ${weekdayName(_date)}, ${dateTitle(_date)} dan seterusnya',
                },
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: EsokColors.of(context).muted),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _titleController,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: typography.titleMedium,
              decoration: _fieldDecoration(hint: 'Apa yang perlu dikerjakan?'),
            ),
            if ((!_dateLocked && parsed.dateFound) || parsed.timeFound)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  [
                    if (!_dateLocked && parsed.dateFound)
                      positionLabel(parsed.date),
                    if (parsed.timeFound) timeText(parsed.time),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: EsokColors.accent),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PickerChip(
                    icon: Icons.calendar_today_outlined,
                    label: dateTitle(effectiveDate),
                    onTap: _dateLocked ? null : _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerChip(
                    icon: Icons.schedule,
                    label: effectiveTime == null
                        ? 'Tambah jam'
                        : timeText(effectiveTime),
                    muted: effectiveTime == null,
                    onTap: _pickTime,
                    onClear: effectiveTime == null
                        ? null
                        : () {
                            if (parsed.timeFound) {
                              _titleController.text = stripTimePhrase(
                                _titleController.text,
                              );
                              _titleController.selection =
                                  TextSelection.collapsed(
                                    offset: _titleController.text.length,
                                  );
                            }
                            setState(() => _time = null);
                          },
                  ),
                ),
              ],
            ),
            if (_canChangeRepeat) ...[
              const SizedBox(height: 10),
              _RepeatField(
                summary: _repeat.summary(effectiveDate, compact: true),
                accessibilitySummary: _repeat.summary(effectiveDate),
                onTap: () => _pickRepeat(effectiveDate, effectiveTime),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              focusNode: _notesFocus,
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: typography.bodyLarge,
              decoration: _fieldDecoration(hint: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.action,
                disabledBackgroundColor: colors.control,
                foregroundColor: colors.onAction,
                disabledForegroundColor: colors.muted,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: typography.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Simpan'),
            ),
            if (isEditing && widget.scope == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.task?.isRecurring == false)
                      TextButton(
                        onPressed:
                            canSave || _notesController.text.trim().isNotEmpty
                            ? _removeSchedule
                            : null,
                        child: const Text('Pindahkan ke Catatan'),
                      ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(const TaskEditorResult.delete()),
                      style: TextButton.styleFrom(
                        foregroundColor: EsokColors.muted,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Hapus tugas'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: EsokColors.muted, fontSize: 16),
      filled: true,
      fillColor: EsokColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EsokColors.ink, width: 1.5),
      ),
    );
  }
}

class _RepeatField extends StatelessWidget {
  const _RepeatField({
    required this.summary,
    required this.accessibilitySummary,
    required this.onTap,
  });

  final String summary;
  final String accessibilitySummary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      label: 'Ulangi',
      value: accessibilitySummary,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.repeat, size: 18, color: colors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        const Text(
                          'Ulangi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          summary,
                          style: TextStyle(fontSize: 13, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18, color: colors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final typography = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Material(
      color: colors.control,
      borderRadius: radius,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 4, 7),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: typography.bodyMedium?.copyWith(
                            color: muted ? colors.muted : colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              tooltip: 'Hapus jam',
              icon: const Icon(Icons.close_rounded, size: 17),
              style: IconButton.styleFrom(
                foregroundColor: colors.muted,
                minimumSize: const Size.square(48),
                visualDensity: VisualDensity.standard,
              ),
            ),
        ],
      ),
    );
  }
}
