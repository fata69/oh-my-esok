import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../ai/gemini_model_catalog.dart';
import '../backup/auto_backup.dart';
import '../data/database.dart';
import '../data/task_dao.dart';
import '../notify/notifier.dart';
import '../state/settings_store.dart';
import '../widget/widget_sync.dart';
import '../update/update_page.dart';
import '../update/update_availability.dart';
import 'ai_model_picker.dart';
import 'chevron.dart';
import 'data_page.dart';
import 'manage_accounts.dart';
import 'manage_categories.dart';
import 'sound_page.dart';
import 'tab_layout.dart';
import 'motion.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _channel = MethodChannel('esok/settings');
  String _version = '—';
  DateTime? _lastBackup;
  bool _backupBusy = false;
  static const _leadOptions = {
    30: '30 menit sebelum tenggat',
    60: '1 jam sebelum tenggat',
    180: '3 jam sebelum tenggat',
    1440: '1 hari sebelum tenggat',
  };

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    });
    AutoBackup.lastBackupAt().then((value) {
      if (!mounted) return;
      setState(() => _lastBackup = value);
    });
  }

  Future<void> _backupNow() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    final ok = await AutoBackup.runIfChanged(force: true);
    final at = await AutoBackup.lastBackupAt();
    if (!mounted) return;
    setState(() {
      _backupBusy = false;
      _lastBackup = at;
    });
    if (ok) {
      _message('Cadangan tersimpan di Download/Oh My Esok');
      return;
    }
    final message = AutoBackup.lastError ?? 'Gagal menulis cadangan.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Simpan manual',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const DataPage())),
        ),
      ),
    );
  }

  String get _backupLabel {
    if (_backupBusy) return 'Menyimpan…';
    final at = _lastBackup;
    if (at == null) return 'Belum ada cadangan';
    final stamp = DateFormat('d MMM, HH.mm', 'id_ID').format(at);
    return 'Terakhir $stamp · Download/Oh My Esok';
  }

  Future<void> _openLeadDuration() async {
    final settings = context.read<SettingsStore>();
    final value = await showModalBottomSheet<int>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _Sheet(
        title: 'Jarak pengingat',
        child: RadioGroup<int>(
          groupValue: settings.leadMinutes,
          onChanged: (minutes) => Navigator.pop(sheetContext, minutes),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in _leadOptions.entries)
                RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  value: option.key,
                  title: Text(option.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (value == null || !mounted) return;
    await settings.setLeadMinutes(value);
    await _reschedule(settings);
  }

  Future<void> _reschedule(SettingsStore settings) async {
    try {
      final db = await AppDatabase.open();
      final tasks = await TaskDao(db).all();
      TaskNotifier.instance.configureLead(
        enabled: settings.leadEnabled,
        minutes: settings.leadMinutes,
      );
      await TaskNotifier.instance.configureSound(
        settings.soundReminder.raw ?? 'coin',
      );
      await TaskNotifier.instance.rescheduleAll(tasks);
    } catch (_) {
      _message('Pengingat belum diperbarui. Coba lagi.');
    }
  }

  Future<void> _toggleLead(bool value) async {
    final settings = context.read<SettingsStore>();
    await settings.setLeadEnabled(value);
    await _reschedule(settings);
  }

  Future<void> _toggleHideAmounts(bool value) async {
    await context.read<SettingsStore>().setHideAmounts(value);
    await WidgetSync.push();
  }

  Future<void> _toggleSoundEnabled(bool value) async {
    await context.read<SettingsStore>().setSoundEnabled(value);
  }

  Future<void> _openExactAlarm() async {
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {
      _message('Pengaturan alarm presisi tidak tersedia.');
    }
  }

  Future<void> _editAiKey() async {
    final settings = context.read<SettingsStore>();
    final value = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AiKeySheet(initial: settings.aiKey),
    );
    if (value == null) return;
    await settings.setAiKey(value.trim());
    if (mounted) {
      _message(
        value.trim().isEmpty
            ? 'API key dihapus.'
            : 'API key disimpan di perangkat ini.',
      );
    }
  }

  Future<void> _editAiModel() async {
    final settings = context.read<SettingsStore>();
    final apiKey = settings.aiKey.trim();
    final modelId = await showAiModelPicker(
      context,
      currentModel: settings.aiModel,
      loadModels: apiKey.isEmpty ? null : () => GeminiModelCatalog.list(apiKey),
      onEditKey: _editAiKey,
    );
    if (!mounted || modelId == null) return;
    if (settings.aiKey.trim() != apiKey) {
      _message('API key berubah. Buka lagi daftar model.');
      return;
    }
    try {
      await settings.setAiModel(modelId);
    } on GeminiModelCatalogException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Model Gemini gagal disimpan.');
    }
  }

  Future<void> _openBattery() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } catch (_) {
      _message('Pengaturan baterai tidak tersedia.');
    }
  }

  Future<void> _showFontLicense() async {
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _Sheet(
        title: 'Lisensi font',
        child: Text(
          'Plus Jakarta Sans · SIL Open Font License 1.1.\n'
          'Hak cipta 2020 The Plus Jakarta Sans Project Authors.',
          style: TextStyle(
            fontSize: 13,
            height: 1.65,
            color: EsokColors.of(context).muted,
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final groups = [
      _SettingsGroup(
        label: 'Tampilan',
        divided: false,
        children: [
          const _SettingsRow(title: 'Tema', icon: Icons.brightness_6_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
            child: _ThemeSelector(
              value: settings.themeMode,
              onChanged: (mode) =>
                  context.read<SettingsStore>().setThemeMode(mode),
            ),
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Pengingat',
        children: [
          _SettingsRow.toggle(
            title: 'Pengingat awal',
            icon: Icons.notifications_none,
            subtitle: 'Tambahan sebelum tenggat',
            value: settings.leadEnabled,
            onToggle: _toggleLead,
          ),
          _SettingsRow(
            title: 'Jarak pengingat',
            icon: Icons.schedule_outlined,
            subtitle: _leadOptions[settings.leadMinutes] ?? _leadOptions[60],
            onTap: _openLeadDuration,
          ),
          _SettingsRow(
            title: 'Alarm presisi',
            icon: Icons.alarm_outlined,
            subtitle: 'Izin Android untuk alarm tepat waktu',
            onTap: _openExactAlarm,
          ),
          _SettingsRow(
            title: 'Optimasi baterai',
            icon: Icons.battery_saver_outlined,
            subtitle: 'Jaga pengingat saat layar mati',
            onTap: _openBattery,
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Suara',
        children: [
          _SettingsRow.toggle(
            title: 'Efek suara',
            icon: Icons.volume_up_outlined,
            subtitle: 'Bunyi saat saldo berubah',
            value: settings.soundEnabled,
            onToggle: _toggleSoundEnabled,
          ),
          _SettingsRow(
            title: 'Pilihan suara',
            icon: Icons.graphic_eq_outlined,
            subtitle: 'Nada agenda, pengingat, dan saldo',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const SoundPage())),
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Keuangan',
        children: [
          _SettingsRow(
            title: 'Dompet',
            icon: Icons.account_balance_wallet_outlined,
            subtitle: 'Saldo tunai, rekening, dan dompet digital',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManageAccountsPage(),
              ),
            ),
          ),
          _SettingsRow(
            title: 'Kategori',
            icon: Icons.category_outlined,
            subtitle: 'Kelompok pemasukan dan pengeluaran',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ManageCategoriesPage(initialKind: 'expense'),
              ),
            ),
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Data',
        children: [
          _SettingsRow(
            title: 'Ekspor & impor',
            icon: Icons.swap_vert,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const DataPage())),
          ),
          _SettingsRow(
            title: 'Cadangkan sekarang',
            icon: Icons.save_alt_rounded,
            subtitle: _backupLabel,
            trailing: _backupBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _backupBusy ? null : _backupNow,
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Pindai struk',
        children: [
          _SettingsRow(
            title: 'API key Gemini',
            icon: Icons.key_outlined,
            subtitle: settings.aiReady
                ? 'Tersimpan di perangkat ini'
                : 'Belum diisi · pakai API key milikmu sendiri',
            onTap: _editAiKey,
          ),
          _SettingsRow(
            title: 'Model Gemini',
            icon: Icons.tune_outlined,
            subtitle: settings.aiModel,
            onTap: _editAiModel,
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Privasi',
        children: [
          _SettingsRow.toggle(
            title: 'Sembunyikan nominal',
            icon: Icons.visibility_off_outlined,
            subtitle: 'Berlaku di widget uang dan Laporan',
            value: settings.hideAmounts,
            onToggle: _toggleHideAmounts,
          ),
        ],
      ),
      _SettingsGroup(
        label: 'Tentang',
        children: [
          const _SettingsRow(
            title: 'Oh My Esok',
            icon: Icons.info_outline,
            subtitle: 'Dikembangkan dan dikelola oleh Fata (@fata69)',
          ),
          ListenableBuilder(
            listenable: UpdateAvailability.instance,
            builder: (context, _) {
              final available = UpdateAvailability.instance.available;
              return _SettingsRow(
                title: 'Pembaruan aplikasi',
                icon: Icons.system_update_outlined,
                subtitle: available ? 'Pembaruan tersedia' : 'Versi $_version',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const UpdatePage()),
                ),
              );
            },
          ),
          _SettingsRow(
            title: 'Lisensi font',
            icon: Icons.description_outlined,
            subtitle: 'SIL Open Font License 1.1',
            onTap: _showFontLicense,
          ),
        ],
      ),
    ];

    return EsokTabLayout(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              EsokTabLayout.gutter,
              0,
              EsokTabLayout.gutter,
              EsokTabLayout.scrollBottomOf(context),
            ),
            children: groups,
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.label,
    required this.children,
    this.divided = true,
  });

  final String label;
  final List<Widget> children;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final colors = EsokColors.of(context);
    final separator = highContrast ? colors.outline : colors.line;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        Material(
          color: colors.subtle,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTileTheme(
            data: const ListTileThemeData(
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              minTileHeight: 48,
              minVerticalPadding: 8,
              horizontalTitleGap: 12,
              minLeadingWidth: 20,
              titleAlignment: ListTileTitleAlignment.center,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (divided && index > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: separator,
                      indent: 44,
                      endIndent: 12,
                    ),
                  child,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = dark ? colors.selected : colors.surface;
    const modes = [
      (ThemeMode.light, 'Terang'),
      (ThemeMode.system, 'Ikut sistem'),
      (ThemeMode.dark, 'Gelap'),
    ];
    const radius = BorderRadius.all(Radius.circular(8));

    return Material(
      color: colors.control,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (mode, label) in modes)
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  selected: mode == value,
                  inMutuallyExclusiveGroup: true,
                  label: label,
                  onTap: () => onChanged(mode),
                  excludeSemantics: true,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: mode == value ? selected : Colors.transparent,
                      borderRadius: radius,
                    ),
                    child: InkWell(
                      onTap: () => onChanged(mode),
                      borderRadius: radius,
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: colors.ink.withValues(alpha: .08),
                      focusColor: colors.ink.withValues(alpha: .16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          child: Center(
                            heightFactor: 1,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w600,
                                color: mode == value
                                    ? colors.ink
                                    : colors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
  }) : value = null,
       onToggle = null;

  const _SettingsRow.toggle({
    required this.title,
    required this.icon,
    required this.value,
    required this.onToggle,
    this.subtitle,
  }) : trailing = null,
       onTap = null;

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    final label = Text(
      title,
      style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final detail = subtitle == null
        ? null
        : Text(subtitle!, style: text.bodyMedium);
    final leading = Icon(icon, size: 20, color: colors.muted);
    if (value case final checked?) {
      return SwitchListTile(
        value: checked,
        onChanged: onToggle,
        secondary: leading,
        title: label,
        subtitle: detail,
      );
    }
    return Semantics(
      container: true,
      child: ListTile(
        onTap: onTap,
        leading: leading,
        title: label,
        subtitle: detail,
        trailing:
            trailing ??
            (onTap == null
                ? null
                : EsokChevron(
                    left: Directionality.of(context) == TextDirection.rtl,
                    color: colors.muted,
                    size: 16,
                  )),
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 7),
      child: Semantics(
        container: true,
        header: true,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: colors.muted),
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: colors.canvas,
      borderRadius: EsokColors.sheetRadius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
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
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiKeySheet extends StatefulWidget {
  const _AiKeySheet({required this.initial});

  final String initial;

  @override
  State<_AiKeySheet> createState() => _AiKeySheetState();
}

class _AiKeySheetState extends State<_AiKeySheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Sheet(
    title: 'API key Gemini',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'API key dari Google AI Studio',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}
