import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../ai/gemini_model_catalog.dart';
import 'motion.dart';
import 'theme.dart';

/// Returns a canonical catalog ID only after the user confirms a selection.
/// A null loader means the settings screen has no API key yet.
Future<String?> showAiModelPicker(
  BuildContext context, {
  required String currentModel,
  required Future<List<GeminiModel>> Function()? loadModels,
  Future<void> Function()? onEditKey,
}) async {
  final result = await showModalBottomSheet<Object>(
    context: context,
    sheetAnimationStyle: EsokMotion.presentation(context),
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: EsokColors.of(context).canvas,
    barrierColor: EsokColors.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _AiModelPicker(
      currentModel: currentModel,
      loadModels: loadModels,
      canEditKey: onEditKey != null,
    ),
  );
  if (result == _PickerExit.editKey && context.mounted) await onEditKey?.call();
  return result is String ? result : null;
}

enum _PickerExit { editKey }

class _AiModelPicker extends StatefulWidget {
  const _AiModelPicker({
    required this.currentModel,
    required this.loadModels,
    required this.canEditKey,
  });

  final String currentModel;
  final Future<List<GeminiModel>> Function()? loadModels;
  final bool canEditKey;

  @override
  State<_AiModelPicker> createState() => _AiModelPickerState();
}

class _AiModelPickerState extends State<_AiModelPicker> {
  final _search = TextEditingController();
  List<GeminiModel>? _models;
  String? _error;
  String? _selectedId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loadModels != null) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loader = widget.loadModels;
    if (loader == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _models = null;
      _selectedId = null;
    });
    try {
      final models = [...await loader()]
        ..sort((a, b) {
          if (a.id == b.id) return 0;
          if (a.id == widget.currentModel) return -1;
          if (b.id == widget.currentModel) return 1;
          final order = a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
          return order != 0 ? order : a.id.compareTo(b.id);
        });
      if (!mounted) return;
      setState(() {
        _models = models;
        _selectedId = models.any((m) => m.id == widget.currentModel)
            ? widget.currentModel
            : null;
        _loading = false;
      });
    } on GeminiModelCatalogException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Daftar model belum bisa dimuat. Coba lagi.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  void _updateSearch(String _) => setState(() => _selectedId = null);

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final theme = Theme.of(context);
    final models = _models ?? const <GeminiModel>[];
    final query = _search.text.trim();
    final term = query.toLowerCase();
    final ready = models.isNotEmpty;
    final typed = ready && query.isNotEmpty
        ? GeminiModelCatalog.resolve(query, models)
        : null;
    final filtered = term.isEmpty
        ? models
        : models.where((model) {
            return model.id == typed?.id ||
                model.displayName.toLowerCase().contains(term) ||
                model.id.toLowerCase().contains(term) ||
                'models/${model.id.toLowerCase()}'.contains(term);
          }).toList();
    final selection = _selectedId ?? typed?.id;
    final canSave = ready && models.any((model) => model.id == selection);
    final screen = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    Widget status(String text) => Semantics(
      liveRegion: true,
      child: Text(text, style: theme.textTheme.bodyMedium),
    );

    Widget retry() => Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
    );

    Widget save() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop(selection)
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Simpan'),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = math.min(
              constraints.maxHeight,
              math.min(screen.height * .84, ready ? 540.0 : 300.0),
            );
            final pinnedSave = ready && height >= 200;
            return SizedBox(
              height: height,
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                            child: Column(
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          'Model Gemini',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Tutup',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ],
                                ),
                                if (ready) ...[
                                  TextField(
                                    controller: _search,
                                    onChanged: _updateSearch,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.search,
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: 'Cari nama atau ID model',
                                      hintStyle: theme.textTheme.bodyMedium,
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Hapus pencarian',
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _search.clear();
                                                _updateSearch('');
                                              },
                                            ),
                                      filled: true,
                                      fillColor: colors.control,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: colors.outline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (query.isEmpty)
                                    Text(
                                      models.any(
                                            (m) => m.id == widget.currentModel,
                                          )
                                          ? 'Daftar model dari Google.'
                                          : 'Model tersimpan tidak ada di daftar Google ini.',
                                      style: theme.textTheme.bodyMedium,
                                    )
                                  else if (filtered.isEmpty)
                                    status('Tidak ada model yang cocok.')
                                  else if (!canSave)
                                    status('Pilih model dari hasil pencarian.'),
                                ] else if (widget.loadModels == null) ...[
                                  status(
                                    'Isi API key Gemini untuk memuat daftar model dari Google.',
                                  ),
                                  if (widget.canEditKey)
                                    Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(
                                          context,
                                          _PickerExit.editKey,
                                        ),
                                        child: const Text('Atur API key'),
                                      ),
                                    ),
                                ] else if (_loading) ...[
                                  status('Memuat daftar model dari Google…'),
                                  const SizedBox(height: 16),
                                  const LinearProgressIndicator(minHeight: 2),
                                ] else if (_error != null) ...[
                                  status(_error!),
                                  retry(),
                                ] else ...[
                                  status(
                                    'Google tidak mengembalikan model untuk API key ini.',
                                  ),
                                  retry(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final model = filtered[index];
                              final selected = model.id == selection;
                              return Semantics(
                                selected: selected,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: colors.line),
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      _selectedId = model.id;
                                    }),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 52,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    model.displayName,
                                                    style: theme
                                                        .textTheme
                                                        .bodyLarge,
                                                  ),
                                                  if (model.displayName !=
                                                      model.id)
                                                    Text(
                                                      model.id,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 24,
                                              child: selected
                                                  ? Icon(
                                                      Icons.check,
                                                      size: 20,
                                                      color: colors.ink,
                                                    )
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (ready && !pinnedSave)
                          SliverToBoxAdapter(child: save()),
                      ],
                    ),
                  ),
                  if (pinnedSave) save(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
