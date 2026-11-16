import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/category.dart';
import '../state/money_store.dart';
import 'category_icon.dart';
import 'chevron.dart';
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
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _NameSheet(
        title: _kind == 'income'
            ? 'Kategori pemasukan'
            : 'Kategori pengeluaran',
        hint: 'Nama kategori',
      ),
    );
    if (name == null || !mounted) return;
    try {
      await context.read<MoneyStore>().addCategory(name, _kind);
    } on NameConflictException {
      _message('Kategori itu sudah ada.');
    }
  }

  Future<void> _rename(MoneyCategory category) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _NameSheet(
        title: 'Ubah nama kategori',
        hint: 'Nama kategori',
        initial: category.name,
      ),
    );
    if (name == null || !mounted) return;
    try {
      await context.read<MoneyStore>().renameCategory(category.id, name);
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EsokColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Handle(),
              _ActionRow(
                label: 'Ubah nama',
                onTap: () {
                  Navigator.pop(context);
                  _rename(category);
                },
              ),
              _ActionRow(
                label: category.archived ? 'Aktifkan lagi' : 'Arsipkan',
                onTap: () {
                  Navigator.pop(context);
                  store.setCategoryArchived(category.id, !category.archived);
                },
              ),
              _ActionRow(
                label: 'Hapus',
                danger: true,
                onTap: count > 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        _delete(category);
                      },
              ),
              if (count > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                  child: Text(
                    'Punya $count transaksi — arsipkan saja agar riwayat tetap punya label.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: EsokColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showArchived() async {
    final store = context.read<MoneyStore>();
    final archived = store.archivedCategories
        .where((category) => category.kind == _kind)
        .toList();
    if (archived.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EsokColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Handle()),
              const SizedBox(height: 8),
              Text(
                'Kategori diarsipkan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: EsokColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final category in archived)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category.name),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      store.setCategoryArchived(category.id, false);
                    },
                    child: const Text('Aktifkan'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
                      style: TextStyle(
                        fontSize: 12,
                        color: EsokColors.muted,
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
            child: CategoryIconView(
              category: category,
              size: 16,
            ),
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
                      style: TextStyle(
                        fontSize: 14.5,
                        color: EsokColors.ink,
                      ),
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: onTap == null
                ? EsokColors.chevron
                : (danger ? EsokColors.lateInk : EsokColors.ink),
          ),
        ),
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

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title, required this.hint, this.initial});

  final String title;
  final String hint;
  final String? initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
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
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              hintText: widget.hint,
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: _submit,
                style: TextButton.styleFrom(foregroundColor: EsokColors.accent),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
