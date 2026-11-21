import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/account.dart';
import '../data/money_transaction.dart';
import '../data/payday_dao.dart';
import '../data/task.dart';
import '../state/money_store.dart';
import '../state/payday_projection.dart';
import '../util/format.dart';
import 'glass_controls.dart';
import 'motion.dart';
import 'tab_layout.dart';
import 'theme.dart';
import 'tx_editor_page.dart';

Future<void> openPaydayPage(BuildContext context) =>
    _push(context, const _PaydayPage());

class PaydayOverview extends StatelessWidget {
  const PaydayOverview({super.key, required this.store});

  final MoneyStore store;

  @override
  Widget build(BuildContext context) {
    final plan = store.paydayPlan;
    if (plan == null) return const SizedBox.shrink();
    final projection = _project(store, plan);
    final firstShort = projection.firstShort;
    final payday = projection.payday;
    final status = firstShort != null
        ? 'Perkiraan kurang ${rupiahText(firstShort.balance.abs())} pada ${_shortDay(firstShort.date)}'
        : payday != null
        ? 'Perkiraan sisa ${rupiahText(projection.remaining)} sampai ${_shortDay(payday)}'
        : 'Atur tanggal gajian dan tagihan';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _PlanRow(
        icon: firstShort == null
            ? Icons.calendar_today_outlined
            : Icons.info_outline,
        title: 'Sampai Gajian',
        subtitle: status,
        iconColor: firstShort == null ? null : _warningInk(context),
        onTap: () async {
          if (plan.isEmpty && !await _editSchedule(context, store)) {
            return;
          }
          if (context.mounted) await openPaydayPage(context);
        },
      ),
    );
  }
}

class _PaydayPage extends StatelessWidget {
  const _PaydayPage();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final plan = store.paydayPlan ?? const PaydayPlan();
    final projection = _project(store, plan);
    final payday = projection.payday;
    final short = projection.firstShort;
    final account = store.accountById(plan.schedule?.accountId ?? '');
    final text = Theme.of(context).textTheme;
    final projectedDates = {
      for (final item in projection.items) (item.bill.id, item.dueDate),
    };
    final now = today();
    final day = dateKey(now);
    final lookAhead = dateKey(DateTime(now.year, now.month + 2));
    final scheduledBills = [
      for (final bill in plan.bills)
        (bill, bill.dueBefore(day, lookAhead).firstOrNull ?? bill.date),
    ];
    final otherRows = [
      for (final (bill, due) in scheduledBills)
        if (!projectedDates.contains((bill.id, due)))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlanRow(
              icon: Icons.receipt_long_outlined,
              title: bill.name,
              subtitle:
                  '${_shortDay(due)} · ${store.accountName(bill.accountId)}',
              trailing: Text(rupiahText(bill.amount), textAlign: TextAlign.end),
              onTap: () =>
                  _push(context, _BillPage(billId: bill.id, dueDate: due)),
            ),
          ),
    ];
    return _PlanPage(
      title: 'Sampai Gajian',
      primaryAction: _AddBillAction(onPressed: () => _addBill(context, store)),
      children: [
        if (payday != null && account != null) ...[
          EsokContentGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      short == null
                          ? 'Perkiraan sisa setelah tagihan'
                          : 'Perkiraan kekurangan',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rupiahText(short?.balance.abs() ?? projection.remaining),
                      style: text.headlineMedium?.copyWith(
                        color: short == null
                            ? EsokColors.incomeInk(Theme.of(context).brightness)
                            : _warningInk(context),
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      short == null
                          ? 'Dari saldo tercatat · ${account.name}'
                          : 'Mulai ${_fullDay(short.date)} · ${account.name}',
                      style: text.bodyMedium,
                    ),
                    if (short != null &&
                        short.balance != projection.remaining) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Menjelang gajian, kurang ${rupiahText(projection.remaining.abs())}',
                        style: text.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _PlanRow(
          icon: CupertinoIcons.calendar,
          title: payday == null
              ? 'Atur jadwal gajian'
              : 'Gajian ${_fullDay(payday)}',
          subtitle: plan.schedule == null
              ? null
              : _frequency(plan.schedule!.monthly),
          onTap: () => _editSchedule(context, store),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            payday == null ? 'Tagihan' : 'Tagihan sebelum gajian',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        if (projection.items.isEmpty && (payday != null || otherRows.isEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              payday == null
                  ? 'Belum ada tagihan.'
                  : 'Belum ada tagihan sebelum gajian.',
              style: text.bodyMedium,
            ),
          ),
        for (final item in projection.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlanRow(
              icon: item.payment == null
                  ? Icons.receipt_long_outlined
                  : Icons.check_rounded,
              title: item.bill.name,
              subtitle: _billSubtitle(item),
              trailing: Text(
                rupiahText(item.bill.amount),
                textAlign: TextAlign.end,
              ),
              onTap: () => _push(
                context,
                _BillPage(billId: item.bill.id, dueDate: item.dueDate),
              ),
            ),
          ),
        if (payday == null)
          ...otherRows
        else if (otherRows.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('Tagihan di luar perkiraan'),
            subtitle: Text('${otherRows.length} tagihan'),
            children: otherRows,
          ),
      ],
    );
  }
}

class _AddBillAction extends StatelessWidget {
  const _AddBillAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(32));
    final colors = EsokColors.of(context);
    return ApplePressable(
      scale: 0.95,
      child: EsokGlass(
        radius: radius,
        child: Material(
          color: Colors.transparent,
          child: TextButton.icon(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: colors.tint,
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: const RoundedRectangleBorder(borderRadius: radius),
            ),
            icon: const Icon(CupertinoIcons.add, size: 19),
            label: const Text('Tambah tagihan'),
          ),
        ),
      ),
    );
  }
}

class _BillPage extends StatefulWidget {
  const _BillPage({required this.billId, required this.dueDate});

  final String billId;
  final String dueDate;

  @override
  State<_BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<_BillPage> {
  bool _working = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } on PaydayWriteException catch (error) {
      if (mounted) _message(context, error.message);
    } catch (_) {
      if (mounted) _message(context, 'Perubahan gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _link(MoneyStore store, PlannedBill bill) async {
    final matches = store.availableBillPayments(bill);
    final transaction = await _showPlanSheet<MoneyTransaction>(
      context,
      builder: (context) => _PlanSheet(
        title: 'Hubungkan transaksi',
        children: [
          Text(
            '${bill.name} · ${rupiahText(bill.amount)} · ${store.accountName(bill.accountId)}',
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text(
              'Belum ada pengeluaran dengan nominal yang sama di dompet ini.',
            )
          else
            for (final match in matches)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _PlanRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: match.note ?? 'Pengeluaran',
                  subtitle: _fullDay(match.date),
                  trailing: Text(rupiahText(match.amount)),
                  onTap: () => Navigator.pop(context, match),
                ),
              ),
        ],
      ),
    );
    if (transaction == null || !mounted) return;
    final confirmed = await _confirm(
      context,
      title: 'Hubungkan pembayaran?',
      content:
          '${transaction.note ?? 'Pengeluaran'} · ${rupiahText(transaction.amount)}',
      action: 'Hubungkan',
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => store.linkBillPayment(bill, widget.dueDate, transaction.id),
    );
  }

  Future<void> _record(MoneyStore store, PlannedBill bill) async {
    if (store.availableBillPayments(bill).isNotEmpty) {
      final confirmed = await _confirm(
        context,
        title: 'Ada pengeluaran yang cocok',
        content:
            'Periksa Hubungkan transaksi jika pembayaran ini sudah tercatat.',
        action: 'Catat baru',
      );
      if (!confirmed || !mounted) return;
    }
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TxEditorPage(
          initialBill: bill,
          saveBillPayment: (transaction) =>
              store.recordBillPayment(bill, widget.dueDate, transaction),
        ),
      ),
    );
    if (saved != null && mounted) {
      _message(context, 'Pembayaran dicatat dan terhubung.');
    }
  }

  Future<void> _remove(MoneyStore store, PlannedBill bill) async {
    final confirmed = await _confirm(
      context,
      title: 'Hapus tagihan?',
      content:
          'Jadwal ${bill.name} akan dihapus. Transaksi yang sudah dicatat tetap ada di Uang.',
      action: 'Hapus',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      await store.deletePlannedBill(bill.id);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final plan = store.paydayPlan;
    final bill = plan?.bills
        .where((item) => item.id == widget.billId)
        .firstOrNull;
    if (bill == null) {
      return const _PlanPage(
        title: 'Tagihan',
        children: [Text('Tagihan ini sudah dihapus.')],
      );
    }
    final payment = plan?.payments
        .where(
          (payment) =>
              payment.billId == bill.id && payment.dueDate == widget.dueDate,
        )
        .firstOrNull;
    final account = store.accountById(bill.accountId);
    final projected = payment == null && plan != null
        ? _project(store, plan).items
              .where(
                (item) =>
                    item.bill.id == bill.id && item.dueDate == widget.dueDate,
              )
              .firstOrNull
        : null;
    final text = Theme.of(context).textTheme;
    return _PlanPage(
      title: bill.name,
      children: [
        Text(
          '${_fullDay(widget.dueDate)} · ${_frequency(bill.monthly)}',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(rupiahText(bill.amount), style: text.headlineMedium),
        const SizedBox(height: 4),
        Text(store.accountName(bill.accountId), style: text.bodyMedium),
        if (projected != null) ...[
          const SizedBox(height: 8),
          Text(
            'Perkiraan saldo setelah tagihan ${rupiahText(projected.balanceAfter)}',
            style: text.bodyMedium,
          ),
        ],
        const SizedBox(height: 20),
        if (payment != null) ...[
          const Text(
            'Pembayaran terhubung',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          FutureBuilder<MoneyTransaction?>(
            future: store.transactionById(payment.transactionId),
            builder: (context, snapshot) {
              final transaction = snapshot.data;
              if (transaction == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PlanRow(
                  icon: Icons.receipt_long_outlined,
                  title: transaction.note ?? 'Pengeluaran',
                  subtitle: _fullDay(transaction.date),
                  trailing: Text(rupiahText(transaction.amount)),
                  onTap: () => Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => TxEditorPage(transaction: transaction),
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _working
                  ? null
                  : () => _run(() => store.unlinkBillPayment(payment)),
              child: const Text('Lepas tautan'),
            ),
          ),
        ] else ...[
          Text(
            'Pembayaran bisa dicatat dari sini atau dihubungkan ke pengeluaran yang sudah ada.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: _working || account?.archived != false
                    ? null
                    : () => _record(store, bill),
                child: const Text('Catat pembayaran'),
              ),
              OutlinedButton(
                onPressed: _working ? null : () => _link(store, bill),
                child: const Text('Hubungkan transaksi'),
              ),
            ],
          ),
          if (account?.archived == true)
            Text(
              'Aktifkan dompet ini untuk mencatat pembayaran baru.',
              style: text.bodyMedium,
            ),
        ],
        const SizedBox(height: 20),
        const Divider(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _working ? null : () => _remove(store, bill),
            child: const Text('Hapus jadwal tagihan'),
          ),
        ),
      ],
    );
  }
}

Future<bool> _editSchedule(BuildContext context, MoneyStore store) async {
  if (store.activeAccounts.isEmpty) {
    _message(context, 'Tambahkan atau aktifkan dompet terlebih dahulu.');
    return false;
  }
  return await _showPlanSheet<bool>(
        context,
        builder: (_) => _PlanForm(store: store, isBill: false),
      ) ??
      false;
}

Future<void> _addBill(BuildContext context, MoneyStore store) async {
  if (store.activeAccounts.isEmpty) {
    _message(context, 'Tambahkan atau aktifkan dompet terlebih dahulu.');
    return;
  }
  await _showPlanSheet<bool>(
    context,
    builder: (_) => _PlanForm(store: store, isBill: true),
  );
}

class _PlanForm extends StatefulWidget {
  const _PlanForm({required this.store, required this.isBill});

  final MoneyStore store;
  final bool isBill;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late final List<Account> _accounts = widget.store.activeAccounts;
  PaydaySchedule? get _schedule => widget.store.paydayPlan?.schedule;
  late String _accountId =
      _accounts
          .where((account) => account.id == _schedule?.accountId)
          .firstOrNull
          ?.id ??
      _accounts.first.id;
  late DateTime? _date = widget.isBill
      ? today()
      : DateTime.tryParse(_schedule?.date ?? '');
  late bool _monthly = widget.isBill ? false : (_schedule?.monthly ?? true);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = today();
    final selected = _date ?? now;
    final first = widget.isBill && selected.isBefore(now) ? selected : now;
    final last = DateTime(now.year + 10, 12, 31);
    final initial = selected.isBefore(first) || selected.isAfter(last)
        ? first
        : selected;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      cancelText: 'Batal',
      confirmText: 'Pilih',
      helpText: widget.isBill ? 'Pilih jatuh tempo' : 'Pilih tanggal gajian',
    );
    if (mounted && date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    final selected = _date;
    if (_saving ||
        selected == null ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (!widget.isBill && !_monthly && selected.isBefore(today())) {
      _message(context, 'Pilih tanggal gajian berikutnya.');
      return;
    }
    setState(() => _saving = true);
    try {
      final store = widget.store;
      if (widget.isBill) {
        await store.addPlannedBill(
          PlannedBill(
            id: const Uuid().v4(),
            name: _name.text.trim(),
            amount: int.parse(_amount.text),
            accountId: _accountId,
            date: dateKey(selected),
            monthly: _monthly,
          ),
        );
      } else {
        await store.savePayday(
          PaydaySchedule(
            accountId: _accountId,
            date: dateKey(selected),
            monthly: _monthly,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on PaydayWriteException catch (error) {
      if (mounted) _message(context, error.message);
    } catch (_) {
      if (mounted) _message(context, 'Perubahan gagal disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: _PlanSheet(
      title: widget.isBill ? 'Tambah tagihan' : 'Jadwal gajian',
      children: [
        if (widget.isBill) ...[
          TextFormField(
            controller: _name,
            maxLength: 54,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nama tagihan',
              hintText: 'Misalnya listrik',
              counterText: '',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Isi nama tagihan.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            maxLength: 9,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              counterText: '',
            ),
            validator: (value) => (int.tryParse(value ?? '') ?? 0) > 0
                ? null
                : 'Isi nominal tagihan.',
          ),
        ] else
          const Text(
            'Pilih tanggal gajian dan dompet yang dipakai untuk perkiraan.',
          ),
        const SizedBox(height: 12),
        _PlanRow(
          icon: Icons.calendar_today_outlined,
          title: widget.isBill ? 'Jatuh tempo' : 'Tanggal gajian',
          subtitle: _date == null ? 'Pilih tanggal' : _fullDay(dateKey(_date!)),
          onTap: _pickDate,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          initialValue: _monthly,
          decoration: const InputDecoration(labelText: 'Ulangi'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Sekali')),
            DropdownMenuItem(value: true, child: Text('Bulanan')),
          ],
          onChanged: (value) => setState(() => _monthly = value ?? false),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: 'Dompet'),
          isExpanded: true,
          items: [
            for (final account in _accounts)
              DropdownMenuItem(
                value: account.id,
                child: Text(account.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) =>
              setState(() => _accountId = value ?? _accountId),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving || _date == null ? null : _save,
          child: Text(widget.isBill ? 'Simpan tagihan' : 'Simpan jadwal'),
        ),
      ],
    ),
  );
}

class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.title,
    required this.children,
    this.primaryAction,
  });

  final String title;
  final List<Widget> children;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EsokColors.of(context).canvas,
    appBar: AppBar(centerTitle: true, title: Text(title)),
    floatingActionButton: primaryAction,
    body: SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          primaryAction == null
              ? 24
              : 82 + MediaQuery.textScalerOf(context).scale(14),
        ),
        children: children,
      ),
    ),
  );
}

class _PlanSheet extends StatelessWidget {
  const _PlanSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final text = Theme.of(context).textTheme;
    return ApplePressable(
      child: Material(
        color: colors.surface,
        borderRadius: EsokColors.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: EsokColors.cardRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              child: LayoutBuilder(
                builder: (context, box) {
                  final value = trailing;
                  final stackValue =
                      value != null &&
                      (box.maxWidth < 270 ||
                          MediaQuery.textScalerOf(context).scale(16) >= 19.5);
                  return Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.control,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          size: 16,
                          color: iconColor ?? colors.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (subtitle != null)
                              Text(subtitle!, style: text.bodyMedium),
                            if (stackValue) ...[
                              const SizedBox(height: 4),
                              value,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (value != null && !stackValue) ...[
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: box.maxWidth * .42,
                          ),
                          child: value,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 15,
                        color: colors.muted,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PaydayProjection _project(MoneyStore store, PaydayPlan plan) =>
    PaydayProjection.build(
      plan,
      today: dateKey(today()),
      balance: store.balanceForAccount(plan.schedule?.accountId ?? ''),
    );

String _shortDay(String day) => shortDateTitle(DateTime.parse(day));

String _fullDay(String day) {
  final date = DateTime.parse(day);
  return '${weekdayName(date)}, ${dateTitle(date)}${date.year == today().year ? '' : ' ${date.year}'}';
}

String _frequency(bool monthly) => monthly ? 'Bulanan' : 'Sekali';

String _billSubtitle(ProjectedBill item) {
  final status = item.payment != null
      ? 'Terhubung'
      : item.dueDate.compareTo(dateKey(today())) < 0
      ? 'Lewat tempo'
      : _frequency(item.bill.monthly);
  return '${_shortDay(item.dueDate)} · $status';
}

Color _warningInk(BuildContext context) =>
    EsokColors.expenseInk(Theme.of(context).brightness);

Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context).push<void>(EsokMotion.route<void>((_) => page));

Future<T?> _showPlanSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  sheetAnimationStyle: EsokMotion.presentation(context),
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: EsokColors.of(context).canvas,
  builder: builder,
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String content,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      animationStyle: EsokMotion.presentation(context),
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
