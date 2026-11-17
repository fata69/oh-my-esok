import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/account.dart';
import '../data/money_transaction.dart';
import '../data/task.dart';
import '../state/money_store.dart';
import '../util/format.dart';
import 'items_sheet.dart';
import 'manage_accounts.dart';
import 'tab_layout.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

class MoneyPage extends StatelessWidget {
  const MoneyPage({super.key});

  static Future<void> createTransaction(BuildContext context) =>
      _openEditor(context, initialDate: today());

  static Future<void> _openEditor(
    BuildContext context, {
    MoneyTransaction? transaction,
    DateTime? initialDate,
  }) async {
    final store = context.read<MoneyStore>();
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            TxEditorPage(transaction: transaction, initialDate: initialDate),
      ),
    );
    if (saved == null || !context.mounted) return;
    await store.setMonth(DateTime.parse(saved));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tersimpan di ${shortDateTitle(DateTime.parse(saved))}'),
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    MoneyStore store,
    MoneyTransaction transaction,
  ) async {
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
      await _openEditor(context, transaction: transaction);
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final grouped = store.monthByDay;

    return EsokTabLayout(
      child: Column(
        children: [
          EsokPeriodHeader(
            title: monthTitle(store.month),
            previousLabel: 'Bulan sebelumnya',
            nextLabel: 'Bulan berikutnya',
            onPrevious: () => store.previousMonth(),
            onNext: () => store.nextMonth(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                EsokTabLayout.gutter,
                4,
                EsokTabLayout.gutter,
                EsokTabLayout.scrollBottomOf(context),
              ),
              children: [
                _BalanceBlock(store: store),
                if (grouped.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'Belum ada transaksi bulan ini.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final entry in grouped.entries) ...[
                    _DayHeader(
                      date: DateTime.parse(entry.key),
                      net: store.netForDay(entry.value),
                    ),
                    for (final transaction in entry.value)
                      _TransactionRow(
                        transaction: transaction,
                        store: store,
                        onTap: transaction.kind == 'adjustment'
                            ? () {}
                            : () => _showActions(context, store, transaction),
                      ),
                  ],
              ],
            ),
          ),
        ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final incomeInk = dark ? const Color(0xFF548CFF) : const Color(0xFF1558D4);
    final expenseInk = dark ? const Color(0xFFFF8836) : const Color(0xFFB64A0B);
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
            fontSize: 34,
            fontWeight: FontWeight.w600,
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
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11.5, color: colors.muted),
                children: [
                  const TextSpan(text: 'Masuk '),
                  TextSpan(
                    text: _flowAmount(store.monthIncome),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: incomeInk,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 11.5, color: colors.muted),
                children: [
                  const TextSpan(text: 'Keluar '),
                  TextSpan(
                    text: _flowAmount(-store.monthExpense),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: expenseInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'PER DOMPET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.09,
                  color: colors.muted,
                ),
              ),
            ),
            TextButton(
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
              child: const Text('Kelola dompet'),
            ),
          ],
        ),
        if (accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Belum ada sumber dana.',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          )
        else
          for (final account in accounts)
            _AccountBalanceRow(
              account: account,
              balance: store.balanceForAccount(account.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageAccountsPage(),
                ),
              ),
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
                'Atur dana awal di Sumber dana agar saldo sesuai.',
                style: TextStyle(fontSize: 11, color: colors.accent),
              ),
            ),
          ),
      ],
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
    final initial = account.name.isEmpty
        ? '?'
        : account.name.substring(0, 1).toUpperCase();
    final color = balance < 0 ? colors.negative : colors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
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
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    Text(
                      accountTypeLabel(account.type),
                      style: TextStyle(fontSize: 10.5, color: colors.muted),
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
  const _DayHeader({required this.date, required this.net});

  final DateTime date;
  final int net;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final color = net < 0
        ? colors.negative
        : net > 0
        ? colors.positive
        : colors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 7),
      child: Container(
        padding: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                moneyDayLabel(date),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              signedNumberText(net),
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.store,
    required this.onTap,
  });

  final MoneyTransaction transaction;
  final MoneyStore store;
  final VoidCallback onTap;

  bool get _isAdjustment => transaction.kind == 'adjustment';

  String get _initial {
    final name = transaction.isTransfer || _isAdjustment
        ? store.accountName(transaction.accountId)
        : store.categoryName(transaction.categoryId);
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

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
    if (transaction.isIncome) {
      return '+${numberText(transaction.amount)}';
    }
    if (transaction.isExpense) {
      if (transaction.amount < 0) {
        return '+${numberText(transaction.amount.abs())}';
      }
      return '−${numberText(transaction.amount)}';
    }
    if (_isAdjustment) {
      return transaction.amount >= 0
          ? '+${numberText(transaction.amount)}'
          : '−${numberText(transaction.amount.abs())}';
    }
    return numberText(transaction.amount);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final amountColor = transaction.isIncome
        ? colors.positive
        : transaction.isExpense
        ? colors.negative
        : colors.inkSoft;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
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
                child: Text(
                  _initial,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                  ),
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
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.muted),
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
