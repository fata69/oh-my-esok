import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/account.dart';
import '../state/money_store.dart';
import '../util/format.dart';
import 'chevron.dart';
import 'money_icon_catalog.dart';
import 'money_icon_picker.dart';
import 'theme.dart';

class ManageAccountsPage extends StatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  State<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends State<ManageAccountsPage> {
  Future<void> _add() async {
    final draft = await showModalBottomSheet<_AccountDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => const _AccountSheet(title: 'Dompet baru'),
    );
    if (draft == null || !mounted) return;
    try {
      await context.read<MoneyStore>().addAccount(
        draft.name,
        draft.type,
        iconKey: draft.iconKey,
      );
    } on NameConflictException {
      _message('Dompet itu sudah ada.');
    }
  }

  Future<void> _editOpening(Account account) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _AmountSheet(
        title: 'Ubah dana awal',
        subtitle: 'Posisi dana sebelum transaksi paling awal.',
        initial: account.openingBalance,
      ),
    );
    if (value == null || !mounted) return;
    await context.read<MoneyStore>().setOpeningBalance(account.id, value);
  }

  Future<void> _adjust(Account account) async {
    final store = context.read<MoneyStore>();
    final current = store.balanceForAccount(account.id);
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _AmountSheet(
        title: 'Koreksi saldo',
        subtitle: 'Saldo menurut catatan: ${numberText(current)}',
        initial: current < 0 ? 0 : current,
      ),
    );
    if (value == null || !mounted) return;
    await store.adjustBalance(account.id, value);
  }

  Future<void> _rename(Account account) async {
    final draft = await showModalBottomSheet<_AccountDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _AccountSheet(
        title: 'Ubah dompet',
        initialName: account.name,
        initialType: account.type,
        initialIconKey: account.iconKey,
        lockType: true,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await context.read<MoneyStore>().renameAccount(
        account.id,
        draft.name,
        iconKey: draft.iconKey,
        clearIcon: draft.iconKey == null && account.iconKey != null,
      );
    } on NameConflictException {
      _message('Dompet itu sudah ada.');
    }
  }

  Future<void> _delete(Account account) async {
    final count = await context.read<MoneyStore>().accountTransactionCount(
      account.id,
    );
    if (!mounted) return;
    if (count > 0) {
      _message('Dompet ini punya $count transaksi. Arsipkan saja.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EsokColors.canvas,
        title: const Text('Hapus dompet?'),
        content: Text('“${account.name}” akan dihapus permanen.'),
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
      await context.read<MoneyStore>().deleteAccount(account.id);
    } on ItemInUseException {
      _message('Dompet ini masih dipakai transaksi.');
    }
  }

  Future<void> _showActions(Account account) async {
    final store = context.read<MoneyStore>();
    final count = await store.accountTransactionCount(account.id);
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
              const Center(child: _Handle()),
              _ActionRow(
                label: 'Ubah dana awal',
                onTap: () {
                  Navigator.pop(context);
                  _editOpening(account);
                },
              ),
              _ActionRow(
                label: 'Koreksi saldo',
                onTap: () {
                  Navigator.pop(context);
                  _adjust(account);
                },
              ),
              _ActionRow(
                label: 'Ubah nama atau ikon',
                onTap: () {
                  Navigator.pop(context);
                  _rename(account);
                },
              ),
              _ActionRow(
                label: account.archived ? 'Aktifkan lagi' : 'Arsipkan',
                onTap: () {
                  Navigator.pop(context);
                  store.setAccountArchived(account.id, !account.archived);
                },
              ),
              _ActionRow(
                label: 'Hapus',
                danger: true,
                onTap: count > 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        _delete(account);
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
    final archived = store.archivedAccounts;
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
                'Dompet diarsipkan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: EsokColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final account in archived)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(account.name),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      store.setAccountArchived(account.id, false);
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

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final active = store.accounts
        .where((account) => !account.archived)
        .toList();
    final archivedCount = store.archivedAccounts.length;
    const groups = [
      ('cash', 'Tunai'),
      ('bank', 'Bank'),
      ('ewallet', 'Dompet digital'),
    ];

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
                      'Dompet',
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Tempat menyimpan uang: tunai, rekening, atau dompet digital.',
                      style: TextStyle(fontSize: 13, color: EsokColors.muted),
                    ),
                  ),
                  _TotalDanaBar(total: store.totalBalance),
                  for (final group in groups) ...[
                    if (active.any((account) => account.type == group.$1)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(
                          group.$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.09,
                            color: EsokColors.muted,
                          ),
                        ),
                      ),
                      for (final account in active.where(
                        (account) => account.type == group.$1,
                      ))
                        _AccountRow(
                          account: account,
                          balance: store.balanceForAccount(account.id),
                          onTap: () => _showActions(account),
                        ),
                    ],
                  ],
                  if (active.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Text(
                        'Belum ada dompet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: EsokColors.muted),
                      ),
                    ),
                  if (archivedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: _showArchived,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            'Lihat $archivedCount dompet diarsipkan',
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
          ],
        ),
      ),
    );
  }
}

class _TotalDanaBar extends StatelessWidget {
  const _TotalDanaBar({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final color = total < 0 ? EsokColors.negative : EsokColors.ink;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: EsokColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TOTAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.09,
                color: EsokColors.muted,
              ),
            ),
          ),
          Text(
            numberText(total),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  final Account account;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = balance < 0 ? EsokColors.negative : EsokColors.ink;
    return SizedBox(
      height: 58,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: EsokColors.soft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: WalletIconView(account: account, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(fontSize: 14.5, color: EsokColors.ink),
                  ),
                  Text(
                    accountTypeLabel(account.type),
                    style: TextStyle(fontSize: 10.5, color: EsokColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              numberText(balance),
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: EsokColors.chevron),
          ],
        ),
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

class _AccountDraft {
  const _AccountDraft(this.name, this.type, this.iconKey);

  final String name;
  final String type;
  final String? iconKey;
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({
    required this.title,
    this.initialName,
    this.initialType = 'cash',
    this.initialIconKey,
    this.lockType = false,
  });

  final String title;
  final String? initialName;
  final String initialType;
  final String? initialIconKey;
  final bool lockType;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final TextEditingController _controller;
  late String _type;
  String? _iconKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _type = widget.initialType;
    _iconKey = widget.initialIconKey;
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
    Navigator.of(context).pop(_AccountDraft(name, _type, _iconKey));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    const types = [
      ('cash', 'Tunai'),
      ('bank', 'Bank'),
      ('ewallet', 'E-wallet'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  hintText: 'Nama dompet',
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
              if (!widget.lockType) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final type in types)
                      GestureDetector(
                        onTap: () => setState(() => _type = type.$1),
                        child: IntrinsicWidth(
                          child: Container(
                            height: 31,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _type == type.$1
                                  ? EsokColors.ink
                                  : EsokColors.soft,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              type.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: _type == type.$1
                                    ? EsokColors.canvas
                                    : EsokColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              MoneyIconField(
                iconSet: MoneyIconSet.wallet,
                value: _iconKey,
                automatic: walletIconSpec(_type, null),
                onChanged: (value) => setState(() => _iconKey = value),
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

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.subtitle,
    required this.initial,
  });

  final String title;
  final String subtitle;
  final int initial;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    Navigator.of(context).pop(int.parse(digits));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(22, 10, 22, 20 + bottom),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: EsokColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: EsokColors.muted,
                ),
                filled: true,
                fillColor: EsokColors.soft,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
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
    );
  }
}

String accountTypeLabel(String type) {
  switch (type) {
    case 'bank':
      return 'bank';
    case 'ewallet':
      return 'e-wallet';
    default:
      return 'tunai';
  }
}
