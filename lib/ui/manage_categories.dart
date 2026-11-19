import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/category.dart';
import '../state/money_store.dart';
import 'action_sheet.dart';
import 'category_icon.dart';
import 'chevron.dart';
import 'money_icon_catalog.dart';
import 'money_icon_picker.dart';
import 'motion.dart';
import 'theme.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key, required this.initialKind});

  final String initialKind;

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  late String _kind;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'income' ? 'income' : 'expense';
  }

  Future<void> _add() async {
    final kind = _kind;
    final draft = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (_) => _CategorySheet(
        title: kind == 'income' ? 'Kategori pemasukan' : 'Kategori pengeluaran',
        kind: kind,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await context.read<MoneyStore>().addCategory(
        draft.name,
        kind,
        iconId: draft.iconId,
      );
    } on NameConflictException {
      _message('Kategori itu sudah ada.');
    }
  }

  Future<void> _edit(MoneyCategory category) async {
    final draft = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (_) => _CategorySheet(
        title: 'Ubah kategori',
        kind: category.kind,
        initial: category,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await context.read<MoneyStore>().renameCategory(
        category.id,
        draft.name,
        iconId: draft.iconId,
        clearIcon: draft.iconId == null && category.iconId != null,
      );
    } on NameConflictException {
      _message('Kategori itu sudah ada.');
    }
  }

  Future<void> _delete(MoneyCategory category) async {
    final count = await context.read<MoneyStore>().categoryTransactionCount(
      category.id,
    );
    if (!mounted) return;
    if (count > 0) {
      _message('Kategori ini punya $count transaksi. Arsipkan saja.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: EsokMotion.presentation(context),
      builder: (context) => AlertDialog(
        backgroundColor: EsokColors.canvas,
        title: const Text('Hapus kategori?'),
        content: Text('“${category.name}” akan dihapus permanen.'),
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
    try {
      await context.read<MoneyStore>().deleteCategory(category.id);
    } on ItemInUseException {
      _message('Kategori ini masih dipakai transaksi.');
    }
  }

  Future<void> _showActions(MoneyCategory category) async {
    final store = context.read<MoneyStore>();
    final count = await store.categoryTransactionCount(category.id);
    if (!mounted) return;
    final action = await showEsokActionSheet<Future<void> Function()>(
      context,
      title: category.name,
      actions: [
        EsokSheetAction(
          () => _edit(category),
          'Ubah nama atau ikon',
          Icons.edit_outlined,
        ),
        EsokSheetAction(
          () => store.setCategoryArchived(category.id, !category.archived),
          category.archived ? 'Aktifkan lagi' : 'Arsipkan',
          category.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
        ),
        EsokSheetAction(
          () => _delete(category),
          'Hapus',
          Icons.delete_outline_rounded,
          destructive: true,
          enabled: count == 0,
        ),
      ],
      footer: count > 0
          ? 'Punya $count transaksi. Arsipkan agar nama kategori tetap terlihat di riwayat.'
          : null,
    );
    if (action != null && mounted) await action();
  }

  Future<void> _showArchived() async {
    final store = context.read<MoneyStore>();
    final archived = store.archivedCategories
        .where((category) => category.kind == _kind)
        .toList();
    if (archived.isEmpty) return;
    final selected = await showModalBottomSheet<MoneyCategory>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EsokSheetPanel(
        title: 'Kategori diarsipkan',
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          shrinkWrap: true,
          itemCount: archived.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) => Row(
            children: [
              Expanded(child: Text(archived[index].name)),
              const SizedBox(width: 8),
              Flexible(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, archived[index]),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('Aktifkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await store.setCategoryArchived(selected.id, false);
    }
  }

  Future<void> _reorder(
    List<MoneyCategory> active,
    int oldIndex,
    int newIndex,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final list = [...active];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await context.read<MoneyStore>().reorderCategories(
      _kind,
      list.map((category) => category.id).toList(),
    );
    if (mounted) setState(() => _busy = false);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final active = store.categories
        .where((category) => category.kind == _kind && !category.archived)
        .toList();
    final archivedCount = store.archivedCategories
        .where((category) => category.kind == _kind)
        .length;

    return Scaffold(
      backgroundColor: EsokColors.canvas,
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
                      'Kategori',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EsokColors.ink,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextButton(
                      onPressed: _add,
                      style: TextButton.styleFrom(
                        foregroundColor: EsokColors.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Tambah'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Text(
                'Kelompokkan transaksi, misalnya Makanan atau Gaji.',
                style: TextStyle(fontSize: 13, color: EsokColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: EsokColors.track,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _KindTab(
                      label: 'Pengeluaran',
                      selected: _kind == 'expense',
                      onTap: () => setState(() => _kind = 'expense'),
                    ),
                    _KindTab(
                      label: 'Pemasukan',
                      selected: _kind == 'income',
                      onTap: () => setState(() => _kind = 'income'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: active.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada kategori.',
                        style: TextStyle(fontSize: 13, color: EsokColors.muted),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      buildDefaultDragHandles: false,
                      itemCount: active.length,
                      onReorderItem: (oldIndex, newIndex) =>
                          _reorder(active, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final category = active[index];
                        return _CategoryRow(
                          key: ValueKey(category.id),
                          category: category,
                          index: index,
                          onTap: () => _showActions(category),
                        );
                      },
                    ),
            ),
            if (archivedCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: GestureDetector(
                  onTap: _showArchived,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Lihat $archivedCount kategori diarsipkan',
                      style: TextStyle(fontSize: 12, color: EsokColors.muted),
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

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? EsokColors.canvas : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1414120E),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? EsokColors.ink : EsokColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.index,
    required this.onTap,
  });

  final MoneyCategory category;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.read<MoneyStore>();
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 16,
              height: 56,
              child: Center(
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: EsokColors.barFill,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: EsokColors.soft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: CategoryIconView(category: category, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(fontSize: 14.5, color: EsokColors.ink),
                    ),
                  ),
                  FutureBuilder<int>(
                    future: store.categoryTransactionCount(category.id),
                    builder: (context, snapshot) => Text(
                      '${snapshot.data ?? ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: EsokColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: EsokColors.chevron,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EsokColors.handle,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

typedef _CategoryDraft = ({String name, String? iconId});

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.title, required this.kind, this.initial});

  final String title;
  final String kind;
  final MoneyCategory? initial;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _controller;
  String? _iconId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.name ?? '');
    _iconId = widget.initial?.iconId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama tidak boleh kosong.');
      return;
    }
    Navigator.of(context).pop<_CategoryDraft>((name: name, iconId: _iconId));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: EsokColors.sheetRadius,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Handle()),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: EsokColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
                style: TextStyle(fontSize: 15, color: EsokColors.ink),
                decoration: InputDecoration(
                  hintText: 'Nama kategori',
                  errorText: _error,
                  filled: true,
                  fillColor: EsokColors.soft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: EsokColors.ink, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              MoneyIconField(
                iconSet: MoneyIconSet.category,
                categoryKind: widget.kind,
                value: _iconId,
                automatic: categoryIconSpec(
                  null,
                  categoryId: widget.initial?.id,
                ),
                onChanged: (value) => setState(() => _iconId = value),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      foregroundColor: EsokColors.accent,
                    ),
                    child: const Text('Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
