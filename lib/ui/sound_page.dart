import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../data/task_dao.dart';
import '../notify/notifier.dart';
import '../state/settings_store.dart';
import '../util/sound_fx.dart';
import '../util/sound_library.dart';
import '../widget/widget_sync.dart';
import 'theme.dart';

class SoundPage extends StatelessWidget {
  const SoundPage({super.key});

  Future<void> _choose(
    BuildContext context, {
    required String title,
    required String selectedId,
    required bool notifyOnly,
    required Future<void> Function(String id) apply,
  }) async {
    final settings = context.read<SettingsStore>();
    final options = notifyOnly
        ? SoundLibrary.notifiable
        : <SoundOption>[SoundOption.silent, ...settings.allSounds];
    final result = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      isScrollControlled: true,
      builder: (_) => _SoundSheet(
        title: title,
        options: options,
        selectedId: selectedId,
        allowImport: !notifyOnly,
      ),
    );
    if (result == null || !context.mounted) return;

    if (result == 'import') {
      final imported = await importSound(context);
      if (imported == null) return;
      await apply(imported.id);
      SoundFx.play(imported);
      return;
    }
    if (result is SoundOption) {
      await apply(result.id);
      SoundFx.play(result);
    }
  }

  Future<void> _applyAndSync(
    Future<void> Function(String id) apply,
    String id,
  ) async {
    await apply(id);
    await WidgetSync.push();
  }

  Future<void> _applyReminder(BuildContext context, String id) async {
    final settings = context.read<SettingsStore>();
    await settings.setSoundReminder(id);
    final raw = settings.soundReminder.raw;
    if (raw == null) return;
    await TaskNotifier.instance.configureSound(raw);
    final db = await AppDatabase.open();
    await TaskNotifier.instance.rescheduleAll(await TaskDao(db).all());
  }

  void _openLibrary(BuildContext context, SettingsStore settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      isScrollControlled: true,
      builder: (_) => _LibrarySheet(settings: settings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      backgroundColor: EsokColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            const _PageHeader(),
            const SizedBox(height: 18),
            _LibraryCard(
              count: settings.allSounds.length,
              onTap: () => _openLibrary(context, settings),
            ),
            const SizedBox(height: 12),
            _SoundCard(
              icon: Icons.notifications_active_outlined,
              title: 'Pengingat tugas',
              subtitle: 'Nada notifikasi saat tenggat mendekat',
              current: settings.soundReminder,
              presets: SoundLibrary.notifiable,
              onPreset: (option) async {
                await _applyReminder(context, option.id);
                SoundFx.play(option);
              },
              onGanti: () => _choose(
                context,
                title: 'Nada pengingat',
                selectedId: settings.soundReminder.id,
                notifyOnly: true,
                apply: (id) => _applyReminder(context, id),
              ),
              actionLabel: 'Kirim notifikasi tes',
              onAction: () => TaskNotifier.instance.showTest(),
            ),
            const SizedBox(height: 12),
            _SoundCard(
              icon: Icons.check_circle_outline,
              title: 'Catatan dicentang',
              subtitle: 'Saat kotak catatan diberi centang',
              current: settings.soundCheck,
              presets: SoundLibrary.builtIn,
              onPreset: (option) async {
                await _applyAndSync(settings.setSoundCheck, option.id);
                SoundFx.play(option);
              },
              onGanti: () => _choose(
                context,
                title: 'Bunyi catatan dicentang',
                selectedId: settings.soundCheck.id,
                notifyOnly: false,
                apply: (id) => _applyAndSync(settings.setSoundCheck, id),
              ),
              actionLabel: 'Coba suara',
              onAction: () => SoundFx.play(settings.soundCheck),
            ),
            const SizedBox(height: 12),
            _SoundCard(
              icon: Icons.remove_circle_outline,
              title: 'Centang dibatalkan',
              subtitle: 'Saat centang catatan dilepas lagi',
              current: settings.soundUncheck,
              presets: SoundLibrary.builtIn,
              onPreset: (option) async {
                await _applyAndSync(settings.setSoundUncheck, option.id);
                SoundFx.play(option);
              },
              onGanti: () => _choose(
                context,
                title: 'Bunyi centang dibatalkan',
                selectedId: settings.soundUncheck.id,
                notifyOnly: false,
                apply: (id) => _applyAndSync(settings.setSoundUncheck, id),
              ),
              actionLabel: 'Coba suara',
              onAction: () => SoundFx.play(settings.soundUncheck),
            ),
            const SizedBox(height: 12),
            _SoundCard(
              icon: Icons.trending_up,
              title: 'Saldo bertambah',
              subtitle: 'Saat pemasukan atau refund dicatat',
              current: settings.soundUp,
              presets: SoundLibrary.builtIn,
              onPreset: (option) async {
                await _applyAndSync(settings.setSoundUp, option.id);
                SoundFx.play(option);
              },
              onGanti: () => _choose(
                context,
                title: 'Bunyi saldo bertambah',
                selectedId: settings.soundUp.id,
                notifyOnly: false,
                apply: (id) => _applyAndSync(settings.setSoundUp, id),
              ),
              actionLabel: 'Coba suara',
              onAction: () => SoundFx.play(settings.soundUp),
            ),
            const SizedBox(height: 12),
            _SoundCard(
              icon: Icons.trending_down,
              title: 'Saldo berkurang',
              subtitle: 'Saat pengeluaran dicatat',
              current: settings.soundDown,
              presets: SoundLibrary.builtIn,
              onPreset: (option) async {
                await _applyAndSync(settings.setSoundDown, option.id);
                SoundFx.play(option);
              },
              onGanti: () => _choose(
                context,
                title: 'Bunyi saldo berkurang',
                selectedId: settings.soundDown.id,
                notifyOnly: false,
                apply: (id) => _applyAndSync(settings.setSoundDown, id),
              ),
              actionLabel: 'Coba suara',
              onAction: () => SoundFx.play(settings.soundDown),
            ),
          ],
        ),
      ),
    );
  }
}

Future<SoundOption?> importSound(BuildContext context) async {
  final settings = context.read<SettingsStore>();
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Pilih file suara',
    type: FileType.audio,
  );
  if (picked == null) return null;
  try {
    final support = await getApplicationSupportDirectory();
    final separator = Platform.pathSeparator;
    final folder = Directory('${support.path}${separator}sounds');
    await folder.create(recursive: true);
    final target = File('${folder.path}$separator${picked.name}');
    await target.writeAsBytes(await picked.readAsBytes(), flush: true);
    final option = SoundOption(
      id: 'file:${target.path}',
      name: picked.name,
      file: target.path,
    );
    await settings.addImportedSound(option);
    return option;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal mengimpor suara.')),
    );
    return null;
  }
}

IconData soundIcon(SoundOption option) {
  switch (option.id) {
    case 'asset:coin.wav':
      return Icons.paid_outlined;
    case 'asset:chime.wav':
      return Icons.notifications_active_outlined;
    case 'asset:pop.wav':
      return Icons.bolt_outlined;
    case 'asset:down.wav':
      return Icons.trending_down;
  }
  if (option.isSilent) return Icons.volume_off_outlined;
  return Icons.music_note_outlined;
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 36,
            height: 40,
            child: Icon(Icons.arrow_back, size: 20),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suara & Notifikasi',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.02,
                  color: EsokColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kustomisasi nada pengingat & apresiasi',
                style: TextStyle(fontSize: 11.5, color: EsokColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: EsokColors.soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: EsokColors.canvas,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.library_music_outlined,
                size: 19,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pustaka suara',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count nada · impor dari penyimpanan',
                    style: TextStyle(fontSize: 11.5, color: EsokColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: EsokColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.presets,
    required this.onPreset,
    required this.onGanti,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final SoundOption current;
  final List<SoundOption> presets;
  final ValueChanged<SoundOption> onPreset;
  final VoidCallback onGanti;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: EsokColors.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: EsokColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: EsokColors.ink),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EsokColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: EsokColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final option in presets) ...[
                Expanded(
                  child: _PresetChip(
                    option: option,
                    selected: option.id == current.id,
                    onTap: () => onPreset(option),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: _PresetChip(
                  option: null,
                  selected: false,
                  onTap: onGanti,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: EsokColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                current.isSilent ? Icons.volume_off_outlined : Icons.audiotrack,
                size: 16,
                color: EsokColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  current.isSilent ? 'Diam' : current.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: EsokColors.ink),
                ),
              ),
              GestureDetector(
                onTap: onGanti,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: EsokColors.canvas,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: EsokColors.lineStrong),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Ganti',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              GestureDetector(
                onTap: () => SoundFx.play(current),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: EsokColors.canvas,
                    shape: BoxShape.circle,
                    border: Border.all(color: EsokColors.lineStrong),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: EsokColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: EsokColors.accent,
                foregroundColor: EsokColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SoundOption? option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFolder = option == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: EsokColors.canvas,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? EsokColors.ink : EsokColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Icon(
          isFolder
              ? Icons.folder_open_outlined
              : soundIcon(option!),
          size: 18,
          color: selected || isFolder ? EsokColors.ink : EsokColors.muted,
        ),
      ),
    );
  }
}

class _SoundSheet extends StatelessWidget {
  const _SoundSheet({
    required this.title,
    required this.options,
    required this.selectedId,
    required this.allowImport,
  });

  final String title;
  final List<SoundOption> options;
  final String selectedId;
  final bool allowImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              allowImport
                  ? 'Ketuk untuk mencoba dan memakai'
                  : 'Nada bawaan untuk notifikasi',
              style: TextStyle(fontSize: 11, color: EsokColors.muted),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in options)
                    _SoundRow(
                      option: option,
                      selected: option.id == selectedId,
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                  if (allowImport) ...[
                    Divider(height: 1, color: EsokColors.line),
                    InkWell(
                      onTap: () => Navigator.of(context).pop('import'),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Icon(
                              Icons.library_add_outlined,
                              size: 18,
                              color: EsokColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Impor dari penyimpanan',
                              style: TextStyle(
                                fontSize: 14,
                                color: EsokColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySheet extends StatelessWidget {
  const _LibrarySheet({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            Text(
              'Pustaka suara',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ketuk untuk mendengarkan',
              style: TextStyle(fontSize: 11, color: EsokColors.muted),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final option in settings.allSounds)
                    InkWell(
                      onTap: () => SoundFx.play(option),
                      child: SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Icon(
                              soundIcon(option),
                              size: 18,
                              color: EsokColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: EsokColors.ink,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: EsokColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Divider(height: 1, color: EsokColors.line),
                  InkWell(
                    onTap: () async {
                      final imported = await importSound(context);
                      if (imported == null || !context.mounted) return;
                      SoundFx.play(imported);
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Icon(
                            Icons.library_add_outlined,
                            size: 18,
                            color: EsokColors.accent,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Impor dari penyimpanan',
                            style: TextStyle(
                              fontSize: 14,
                              color: EsokColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: EsokColors.handle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SoundOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? EsokColors.accent : EsokColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? EsokColors.ink : EsokColors.inkSoft,
                ),
              ),
            ),
            if (!option.isSilent)
              Icon(
                Icons.volume_up_outlined,
                size: 16,
                color: EsokColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}
