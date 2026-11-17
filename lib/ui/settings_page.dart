import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import 'ai_model_picker.dart';
import 'data_page.dart';
import 'manage_accounts.dart';
import 'manage_categories.dart';
import 'sound_page.dart';
import 'tab_layout.dart';
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
    if (at == null) return 'Belum ada · ketuk untuk membuat';
    final stamp = DateFormat('d MMM, HH.mm', 'id_ID').format(at);
    return 'Terakhir $stamp · Download/Oh My Esok';
  }

  Future<void> _openLeadDuration() async {
    final settings = context.read<SettingsStore>();
    final value = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (_) => _Sheet(
        title: 'Pengingat awal',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              (30, '30 menit sebelum tenggat'),
              (60, '1 jam sebelum tenggat'),
              (180, '3 jam sebelum tenggat'),
              (1440, '1 hari sebelum tenggat'),
            ])
              _SheetChoice(
                label: option.$2,
                selected: settings.leadMinutes == option.$1,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (value == null || !mounted) return;
    await context.read<SettingsStore>().setLeadMinutes(value);
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final settings = context.read<SettingsStore>();
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
  }

  Future<void> _toggleLead(bool value) async {
    await context.read<SettingsStore>().setLeadEnabled(value);
    await _reschedule();
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
    final value = await _promptText(
      title: 'API key Gemini',
      hint: 'Tempel API key dari Google AI Studio',
      initial: settings.aiKey,
      obscure: true,
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

  Future<String?> _promptText({
    required String title,
    required String hint,
    required String initial,
    required bool obscure,
  }) {
    final controller = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: EsokColors.of(sheetContext).canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
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
                      color: EsokColors.of(sheetContext).handle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: EsokColors.of(sheetContext).ink,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: TextStyle(
                    fontSize: 14,
                    color: EsokColors.of(sheetContext).ink,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: EsokColors.of(sheetContext).muted,
                    ),
                    filled: true,
                    fillColor: EsokColors.of(sheetContext).soft,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: EsokColors.of(sheetContext).accent,
                      foregroundColor: EsokColors.of(sheetContext).onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
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
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
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

  String get _leadLabel {
    final settings = context.watch<SettingsStore>();
    if (!settings.leadEnabled) return 'Nonaktif';
    switch (settings.leadMinutes) {
      case 30:
        return '30 menit sebelum tenggat';
      case 180:
        return '3 jam sebelum tenggat';
      case 1440:
        return '1 hari sebelum tenggat';
      default:
        return '1 jam sebelum tenggat';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return EsokTabLayout(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          EsokTabLayout.gutter,
          0,
          EsokTabLayout.gutter,
          EsokTabLayout.scrollBottomOf(context),
        ),
        children: [
          _SettingsGroup(
            label: 'Tampilan',
            children: [
              const _SettingsRow(
                title: 'Tema',
                subtitle: 'Ikuti setelan Android secara default',
                icon: Icons.brightness_6_outlined,
              ),
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
            label: 'Notifikasi',
            children: [
              _SettingsRow(
                title: 'Pengingat awal',
                icon: Icons.notifications_none,
                subtitle: _leadLabel,
                onTap: settings.leadEnabled ? _openLeadDuration : null,
                trailing: _Toggle(
                  value: settings.leadEnabled,
                  onChanged: _toggleLead,
                ),
              ),
              _SettingsRow(
                title: 'Alarm presisi',
                icon: Icons.alarm_outlined,
                subtitle: 'Diperlukan agar notifikasi tepat waktu',
                trailing: _Trailing('Atur ›'),
                onTap: _openExactAlarm,
              ),
              _SettingsRow(
                title: 'Optimasi baterai',
                icon: Icons.battery_saver_outlined,
                subtitle: 'Agar One UI tidak menahan pengingat',
                trailing: _Trailing('Atur ›'),
                onTap: _openBattery,
              ),
            ],
          ),
          _SettingsGroup(
            label: 'Suara',
            children: [
              _SettingsRow(
                title: 'Efek suara',
                icon: Icons.volume_up_outlined,
                subtitle: 'Bunyi saat saldo berubah',
                trailing: _Toggle(
                  value: settings.soundEnabled,
                  onChanged: _toggleSoundEnabled,
                ),
              ),
              _SettingsRow(
                title: 'Suara & Notifikasi',
                icon: Icons.graphic_eq_outlined,
                subtitle: 'Nada pengingat, apresiasi, dan saldo',
                trailing: const _Trailing('›'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SoundPage()),
                ),
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
                trailing: const _Trailing('›'),
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
                trailing: const _Trailing('›'),
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
                trailing: _Trailing('›'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DataPage()),
                ),
              ),
              _SettingsRow(
                title: 'Cadangan otomatis',
                icon: Icons.cloud_upload_outlined,
                subtitle: _backupLabel,
                trailing: _backupBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const _Trailing('Sekarang ›'),
                onTap: _backupNow,
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
                trailing: const _Trailing('Atur ›'),
                onTap: _editAiKey,
              ),
              _SettingsRow(
                title: 'Model',
                icon: Icons.tune_outlined,
                subtitle: settings.aiModel,
                trailing: const _Trailing('Pilih ›'),
                onTap: _editAiModel,
              ),
            ],
          ),
          _SettingsGroup(
            label: 'Privasi',
            children: [
              _SettingsRow(
                title: 'Sembunyikan nominal',
                icon: Icons.visibility_off_outlined,
                subtitle: 'Berlaku di widget uang dan Laporan',
                trailing: _Toggle(
                  value: settings.hideAmounts,
                  onChanged: _toggleHideAmounts,
                ),
              ),
            ],
          ),
          _SettingsGroup(
            label: 'Tentang',
            children: [
              _SettingsRow(
                title: 'Pembaruan aplikasi',
                icon: Icons.system_update_outlined,
                subtitle: 'Versi $_version',
                trailing: const _Trailing('Periksa ›'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const UpdatePage()),
                ),
              ),
              const _SettingsRow(
                title: 'Oh My Esok',
                icon: Icons.info_outline,
                subtitle: 'Dikembangkan dari Esok oleh notSeraphimXD',
              ),
              _SettingsRow(
                title: 'Lisensi font',
                icon: Icons.description_outlined,
                trailing: const _Trailing('OFL 1.1 ›'),
                onTap: _showFontLicense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final colors = EsokColors.of(context);
    final surface = dark ? const Color(0xFF151515) : const Color(0xFFF1F3F5);
    final separator = highContrast
        ? colors.outline
        : dark
        ? const Color(0xFF303030)
        : const Color(0xFFDADDE1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        Material(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0 && children[i] is _SettingsRow)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _SettingsRow.labelInset,
                      end: 12,
                    ),
                    child: Divider(height: 1, thickness: 1, color: separator),
                  ),
                children[i],
              ],
            ],
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
    final track = dark ? const Color(0xFF232323) : const Color(0xFFE4E7EB);
    final selected = dark ? const Color(0xFF3A3A3A) : colors.surface;
    const modes = [
      (ThemeMode.light, 'Terang'),
      (ThemeMode.system, 'Ikut sistem'),
      (ThemeMode.dark, 'Gelap'),
    ];
    const radius = BorderRadius.all(Radius.circular(8));

    return Material(
      color: track,
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

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final disabled = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: disabled ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutQuint,
        width: 40,
        height: 23,
        decoration: BoxDecoration(
          color: value ? colors.action : colors.line,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: disabled
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutQuint,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: value ? colors.onAction : colors.surface,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
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
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  static const labelInset = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: colors.ink.withValues(alpha: .08),
      focusColor: colors.ink.withValues(alpha: .10),
      child: Container(
        constraints: BoxConstraints(minHeight: subtitle == null ? 48 : 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: Icon(icon, size: 19, color: colors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.28,
                        color: colors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.36,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .36,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Text(
      text,
      textAlign: TextAlign.end,
      style: TextStyle(fontSize: 11.5, color: colors.muted),
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
      padding: const EdgeInsetsDirectional.fromSTEB(12, 19, 12, 7),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
            color: colors.muted,
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
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
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? colors.accent : colors.muted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? colors.ink : colors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
