import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/account.dart';
import '../data/money_transaction.dart';
import '../data/task.dart';
import '../state/money_store.dart';
import '../util/format.dart';
import 'category_icon.dart';
import 'items_sheet.dart';
import 'manage_accounts.dart';
import 'money_icon_catalog.dart';
import 'month_picker.dart';
import 'tab_layout.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key});

  static Future<void> createTransaction(BuildContext context) =>
      _openEditor(context, initialDate: today());

  @override
  State<MoneyPage> createState() => _MoneyPageState();

  static Future<void> _openEditor(
    BuildContext context, {
    MoneyTransaction? transaction,
    DateTime? initialDate,
    bool revealSavedMonth = true,
  }) async {
    final store = context.read<MoneyStore>();
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            TxEditorPage(transaction: transaction, initialDate: initialDate),
      ),
    );
    if (saved == null || !context.mounted) return;
    if (revealSavedMonth) await store.setMonth(DateTime.parse(saved));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tersimpan di ${shortDateTitle(DateTime.parse(saved))}'),
      ),
    );
  }

  static Future<void> _showActions(
    BuildContext context,
    MoneyStore store,
    MoneyTransaction transaction, {
    bool revealSavedMonth = true,
  }) async {
    if (transaction.kind == 'adjustment') return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: EsokColors.scrim,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: EsokColors.of(sheetContext).canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              _TxActionRow(
                label: 'Ubah',
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              if (transaction.detail != null &&
                  transaction.detail!.trim().isNotEmpty)
                _TxActionRow(
                  label: 'Rincian barang',
                  onTap: () => Navigator.pop(sheetContext, 'items'),
                ),
              _TxActionRow(
                label: 'Hapus',
                danger: true,
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      await _openEditor(
        context,
        transaction: transaction,
        revealSavedMonth: revealSavedMonth,
      );
      return;
    }
    if (action == 'items') {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: EsokColors.scrim,
        isScrollControlled: true,
        builder: (_) =>
            ItemsSheet(detail: transaction.detail!, total: transaction.amount),
      );
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: EsokColors.of(dialogContext).canvas,
          title: const Text('Hapus transaksi?'),
          content: const Text('Transaksi ini akan dihapus permanen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (confirmed == true) await store.deleteTransaction(transaction.id);
    }
  }
}

enum _LedgerKind {
  all('Semua'),
  income('Pemasukan'),
  expense('Pengeluaran'),
  transfer('Transfer');

  const _LedgerKind(this.label);
  final String label;
}

typedef _LedgerFilter = ({_LedgerKind kind, bool newestFirst});

class _MoneyPageState extends State<MoneyPage> {
  static const _defaultFilter = (kind: _LedgerKind.all, newestFirst: true);
  _LedgerFilter _filter = _defaultFilter;

  Future<void> _editFilter() async {
    final filter = await showModalBottomSheet<_LedgerFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LedgerFilterSheet(initial: _filter),
    );
    if (mounted && filter != null) setState(() => _filter = filter);
  }

  bool _matches(MoneyTransaction transaction) => switch (_filter.kind) {
    _LedgerKind.all => true,
    _LedgerKind.income => transaction.isIncome,
    _LedgerKind.expense => transaction.isExpense,
    _LedgerKind.transfer => transaction.isTransfer,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final grouped = store.monthByDay;
    final dates = grouped.keys.toList()
      ..sort((a, b) => _filter.newestFirst ? b.compareTo(a) : a.compareTo(b));
    final visible = <String, List<MoneyTransaction>>{};
    for (final date in dates) {
      final rows = grouped[date]!.where(_matches).toList();
      if (rows.isNotEmpty) {
        visible[date] = _filter.newestFirst ? rows : rows.reversed.toList();
      }
    }
    final filterActive = _filter != _defaultFilter;

    return EsokTabLayout(
      period: EsokMonthHeader(
        month: store.month,
        onPrevious: store.previousMonth,
        onNext: store.nextMonth,
        onSelected: store.setMonth,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          EsokTabLayout.gutter,
          4,
          EsokTabLayout.gutter,
          EsokTabLayout.scrollBottomOf(context),
        ),
        children: [
          _BalanceBlock(store: store),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Transaksi',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _editFilter,
                icon: Icon(
                  filterActive ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 17,
                ),
                label: const Text('Filter'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: EsokContentGroup(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const _TransactionSearchPage(),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 22),
                        SizedBox(width: 10),
                        Expanded(child: Text('Cari transaksi')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filterActive)
            Text(
              '${_filter.kind.label} · ${_filter.newestFirst ? 'Terbaru dulu' : 'Terlama dulu'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                grouped.isEmpty
                    ? 'Belum ada transaksi bulan ini.'
                    : 'Tidak ada transaksi yang cocok dengan filter.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final entry in visible.entries) ...[
              _DayHeader(
                date: DateTime.parse(entry.key),
                net: _filter.kind == _LedgerKind.all
                    ? store.netForDay(entry.value)
                    : null,
              ),
              for (final (index, transaction) in entry.value.indexed)
                _TransactionRow(
                  key: ValueKey(transaction.id),
                  first: index == 0,
                  last: index == entry.value.length - 1,
                  transaction: transaction,
                  store: store,
                  onTap: () =>
                      MoneyPage._showActions(context, store, transaction),
                ),
            ],
        ],
      ),
    );
  }
}

class _TransactionSearchPage extends StatefulWidget {
  const _TransactionSearchPage();

  @override
  State<_TransactionSearchPage> createState() => _TransactionSearchPageState();
}

class _TransactionSearchPageState extends State<_TransactionSearchPage> {
  final _search = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    final query = _search.text.trim();
    final results = store.searchTransactions(query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari transaksi'),
        centerTitle: true,
        backgroundColor: colors.canvas,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EsokTabLayout.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _search,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Catatan, kategori, atau dompet',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus pencarian',
                          onPressed: () {
                            setState(_search.clear);
                            _focus.requestFocus();
                          },
                          icon: const Icon(Icons.close, size: 20),
                        ),
                  filled: true,
                  fillColor: colors.control,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    query.isEmpty
                        ? 'Cari di semua bulan.'
                        : '${results.length} transaksi · Semua bulan',
                    style: text.bodyMedium,
                  ),
                ),
              ),
              if (query.isNotEmpty && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Tidak ada transaksi yang cocok.',
                    style: text.bodyLarge,
                  ),
                ),
              if (results.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: results.length,
                    itemBuilder: (_, index) {
                      final transaction = results[index];
                      final first =
                          index == 0 ||
                          results[index - 1].date != transaction.date;
                      final last =
                          index == results.length - 1 ||
                          results[index + 1].date != transaction.date;
                      final date = first
                          ? DateTime.tryParse(transaction.date)
                          : null;

                      return Column(
                        key: ValueKey(transaction.id),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (first)
                            _DayHeader(date: date, net: null, showYear: true),
                          _TransactionRow(
                            first: first,
                            last: last,
                            transaction: transaction,
                            store: store,
                            onTap: () {
                              _focus.unfocus();
                              MoneyPage._showActions(
                                context,
                                store,
                                transaction,
                                revealSavedMonth: false,
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerFilterSheet extends StatefulWidget {
  const _LedgerFilterSheet({required this.initial});

  final _LedgerFilter initial;

  @override
  State<_LedgerFilterSheet> createState() => _LedgerFilterSheetState();
}

class _LedgerFilterSheetState extends State<_LedgerFilterSheet> {
  late _LedgerFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget choices<T>(
      List<(T, String)> options,
      T value,
      ValueChanged<T> onTap,
    ) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (option, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == option,
            onSelected: (_) => onTap(option),
          ),
      ],
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter transaksi', style: text.titleLarge),
            const SizedBox(height: 5),
            Text(
              'Hanya mengubah riwayat bulan ini. Saldo tetap sama.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text('Jenis transaksi', style: text.bodyMedium),
            choices(
              [for (final kind in _LedgerKind.values) (kind, kind.label)],
              _draft.kind,
              (kind) => setState(
                () => _draft = (kind: kind, newestFirst: _draft.newestFirst),
              ),
            ),
            const SizedBox(height: 14),
            Text('Urutkan', style: text.bodyMedium),
            choices(
              const [(true, 'Terbaru dulu'), (false, 'Terlama dulu')],
              _draft.newestFirst,
              (newestFirst) => setState(
                () => _draft = (kind: _draft.kind, newestFirst: newestFirst),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, _draft),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Terapkan'),
            ),
            if (_draft != _MoneyPageState._defaultFilter)
              TextButton(
                onPressed: () =>
                    setState(() => _draft = _MoneyPageState._defaultFilter),
                child: const Text('Reset filter'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TxActionRow extends StatelessWidget {
  const _TxActionRow({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
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
            color: danger ? colors.lateInk : colors.ink,
          ),
        ),
      ),
    );
  }
}

class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({required this.store});

  final MoneyStore store;

  String _flowAmount(int value) {
    final sign = value < 0 ? '−' : (value > 0 ? '+' : '');
    return '$sign${rupiahText(value.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final brightness = Theme.of(context).brightness;
    final incomeInk = EsokColors.incomeInk(brightness);
    final expenseInk = EsokColors.expenseInk(brightness);
    final total = store.totalBalance;
    final totalColor = total < 0 ? colors.negative : colors.ink;
    final accounts = store.activeAccounts;
    final allOpeningZero = accounts.every(
      (account) => account.openingBalance == 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'TOTAL DANA',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.09,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          numberText(total),
          style: TextStyle(
            fontSize: 39,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.03,
            color: totalColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 4,
          children: [
            _flow(
              'Masuk',
              _flowAmount(store.monthIncome),
              Icons.south_west_rounded,
              incomeInk,
              colors.muted,
            ),
            _flow(
              'Keluar',
              _flowAmount(-store.monthExpense),
              Icons.north_east_rounded,
              expenseInk,
              colors.muted,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Dompet',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              flex: 2,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManageAccountsPage(),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.ink,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Kelola dompet', textAlign: TextAlign.end),
              ),
            ),
          ],
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Belum ada dompet.',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          )
        else
          EsokContentGroup(
            children: [
              for (final (index, account) in accounts.indexed) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 52, endIndent: 12),
                _AccountBalanceRow(
                  account: account,
                  balance: store.balanceForAccount(account.id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ManageAccountsPage(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        if (allOpeningZero && total < 0)
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManageAccountsPage(),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Atur dana awal di Kelola dompet agar saldo sesuai.',
                style: TextStyle(fontSize: 11, color: colors.accent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _flow(
    String label,
    String amount,
    IconData icon,
    Color ink,
    Color muted,
  ) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12.5, color: muted),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Icon(icon, size: 14, color: ink),
            ),
          ),
          TextSpan(text: '$label '),
          TextSpan(
            text: amount,
            style: TextStyle(fontWeight: FontWeight.w600, color: ink),
          ),
        ],
      ),
    );
  }
}

class _AccountBalanceRow extends StatelessWidget {
  const _AccountBalanceRow({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final color = balance < 0 ? colors.negative : colors.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _LedgerColumns(
          details: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.soft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: WalletIconView(account: account, size: 16),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      accountTypeLabel(account.type),
                      style: TextStyle(fontSize: 11.5, color: colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          amount: Text(
            numberText(balance),
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.net,
    this.showYear = false,
  });

  final DateTime? date;
  final int? net;
  final bool showYear;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final day = date;
    final label = day == null
        ? 'Tanggal tidak tersedia'
        : '${moneyDayLabel(day)}${showYear ? ' ${day.year}' : ''}';
    final amount = net;
    final color = (amount ?? 0) < 0
        ? colors.negative
        : (amount ?? 0) > 0
        ? colors.positive
        : colors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (amount != null)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Text(
                  signedNumberText(amount),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    super.key,
    required this.first,
    required this.last,
    required this.transaction,
    required this.store,
    required this.onTap,
  });

  final bool first;
  final bool last;
  final MoneyTransaction transaction;
  final MoneyStore store;
  final VoidCallback onTap;

  bool get _isAdjustment => transaction.kind == 'adjustment';

  String get _title {
    final note = transaction.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    if (transaction.isTransfer) return 'Pindah';
    if (_isAdjustment) return 'Koreksi saldo';
    return store.categoryName(transaction.categoryId);
  }

  String get _subtitle {
    if (transaction.isTransfer) {
      return '${store.accountName(transaction.accountId)} → '
          '${store.accountName(transaction.toAccountId)}';
    }
    if (_isAdjustment) {
      return '${store.accountName(transaction.accountId)} · Penyesuaian';
    }
    return '${store.categoryName(transaction.categoryId)} · '
        '${store.accountName(transaction.accountId)}';
  }

  String get _amount {
    if (transaction.isTransfer) return numberText(transaction.amount);
    final effect = transaction.isExpense
        ? -transaction.amount
        : transaction.amount;
    final sign = effect < 0
        ? '−'
        : effect > 0
        ? '+'
        : '';
    return '$sign${numberText(effect.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final amountColor = transaction.isTransfer || _isAdjustment
        ? colors.inkSoft
        : colors.ink;
    final brightness = Theme.of(context).brightness;
    final iconColor = transaction.isIncome
        ? EsokColors.incomeInk(brightness)
        : transaction.isExpense
        ? EsokColors.expenseInk(brightness)
        : colors.muted;
    final category = transaction.isTransfer || _isAdjustment
        ? null
        : store.categories
              .where((item) => item.id == transaction.categoryId)
              .firstOrNull;
    final row = InkWell(
      onTap: _isAdjustment ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: _LedgerColumns(
          details: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.soft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: category != null
                    ? CategoryIconView(category: category, size: 16)
                    : Icon(
                        transaction.isTransfer
                            ? Icons.swap_horiz_rounded
                            : _isAdjustment
                            ? Icons.tune_rounded
                            : transaction.isIncome
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 16,
                        color: iconColor,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          amount: Text(
            _amount,
            style: TextStyle(
              fontSize: 14,
              color: amountColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
    return EsokGroupedRow(
      first: first,
      last: last,
      child: Column(
        children: [
          if (!first) const Divider(height: 1, indent: 54, endIndent: 12),
          row,
        ],
      ),
    );
  }
}

class _LedgerColumns extends StatelessWidget {
  const _LedgerColumns({required this.details, required this.amount});

  final Widget details;
  final Widget amount;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 240 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: 4),
              Align(alignment: AlignmentDirectional.centerEnd, child: amount),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 10),
            amount,
          ],
        );
      },
    );
  }
}
