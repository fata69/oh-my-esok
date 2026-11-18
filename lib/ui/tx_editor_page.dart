import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../ai/receipt_scanner.dart';
import '../data/account.dart';
import '../data/category.dart';
import '../data/money_transaction.dart';
import '../data/payday_dao.dart';
import '../data/task.dart';
import '../receipt/receipt_inbox.dart';
import '../state/money_store.dart';
import '../state/settings_store.dart';
import '../util/format.dart';
import '../util/sound_fx.dart';
import 'category_icon.dart';
import 'items_sheet.dart';
import 'manage_accounts.dart';
import 'money_icon_catalog.dart';
import 'money_icon_picker.dart';
import 'receipt_scan_review.dart';
import 'motion.dart';
import 'theme.dart';

class TxEditorPage extends StatefulWidget {
  const TxEditorPage({
    super.key,
    this.transaction,
    this.initialDate,
    this.initialKind = 'expense',
    this.initialBill,
    this.saveBillPayment,
    this.receiptImage,
  }) : assert((initialBill == null) == (saveBillPayment == null)),
       assert(initialBill == null || transaction == null),
       assert(
         receiptImage == null || (transaction == null && initialBill == null),
       );

  final MoneyTransaction? transaction;
  final DateTime? initialDate;
  final String initialKind;
  final PlannedBill? initialBill;
  final Future<void> Function(MoneyTransaction)? saveBillPayment;
  final File? receiptImage;

  @override
  State<TxEditorPage> createState() => _TxEditorPageState();
}

class _TxEditorPageState extends State<TxEditorPage> {
  late String _kind;
  DateTime? _date;
  int _amount = 0;
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  String? _detail;
  late final TextEditingController _noteController;
  bool _creatingCategory = false;
  final _categoryNameController = TextEditingController();
  final _categoryScroll = ScrollController(keepScrollOffset: false);
  bool _addingCategory = false;
  String? _draftCategoryIconId;
  String? _categoryError;
  bool _saving = false;
  bool _scanning = false;
  bool _manualKindChosen = false;
  bool _hasScanDraft = false;
  late final String _entryId = widget.transaction?.id ?? const Uuid().v4();

  bool get _isEditing => widget.transaction != null;
  bool get _isTransfer => _kind == 'transfer';
  bool get _sameKind => widget.transaction?.kind == _kind;
  int get _signedAmount =>
      _sameKind && widget.transaction!.amount < 0 ? -_amount : _amount;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    final bill = widget.initialBill;
    _kind = transaction?.kind ?? widget.initialKind;
    _manualKindChosen =
        transaction != null || bill != null || widget.initialKind != 'expense';
    _amount = transaction?.amount.abs() ?? bill?.amount ?? 0;
    _categoryId =
        transaction?.categoryId ?? (bill == null ? null : 'cat-exp-tagihan');
    _accountId = transaction?.accountId ?? bill?.accountId;
    _toAccountId = transaction?.toAccountId;
    _detail = transaction?.detail;
    _date = transaction == null
        ? dateOnly(widget.initialDate ?? today())
        : DateTime.parse(transaction.date);
    _noteController = TextEditingController(
      text: transaction?.note ?? bill?.name ?? '',
    );
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _ensureSelections();
        if (widget.receiptImage != null) await _scanReceipt();
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _categoryNameController.dispose();
    _categoryScroll.dispose();
    super.dispose();
  }

  void _ensureSelections() {
    final store = context.read<MoneyStore>();
    final categories = _kind == 'income'
        ? store.incomeCategories
        : store.expenseCategories;
    final accounts = store.activeAccounts;
    var changed = false;
    if (!_hasScanDraft &&
        !_isTransfer &&
        (_categoryId == null ||
            !categories.any((category) => category.id == _categoryId))) {
      final preferredCategory = widget.initialBill != null || categories.isEmpty
          ? null
          : categories.first.id;
      changed = _categoryId != preferredCategory;
      _categoryId = preferredCategory;
    }
    if (_accountId == null ||
        (!_isEditing && !accounts.any((account) => account.id == _accountId))) {
      _accountId = accounts.isEmpty ? null : accounts.first.id;
      changed = true;
    }
    if (_isTransfer &&
        (_toAccountId == null ||
            (!_isEditing &&
                !accounts.any((account) => account.id == _toAccountId)) ||
            _toAccountId == _accountId)) {
      final other = accounts
          .where((account) => account.id != _accountId)
          .firstOrNull;
      _toAccountId = other?.id;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  void _pressKey(String key) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    if (key == 'back') {
      setState(() => _amount = _amount ~/ 10);
      return;
    }
    if (key == '000') {
      if (_amount == 0) return;
      setState(() {
        final next = _amount * 1000;
        _amount = next > 999999999999 ? 999999999999 : next;
      });
      return;
    }
    final digit = int.tryParse(key);
    if (digit == null) return;
    setState(() {
      final next = _amount * 10 + digit;
      _amount = next > 999999999999 ? 999999999999 : next;
    });
  }

  void _changeKind(String kind) {
    if (_addingCategory) return;
    final firstChoice = !_manualKindChosen;
    _manualKindChosen = true;
    if (_kind == kind) {
      if (firstChoice) setState(() {});
      return;
    }
    setState(() {
      _kind = kind;
      _creatingCategory = false;
      _draftCategoryIconId = null;
      _categoryError = null;
      if (kind == 'transfer') {
        _categoryId = null;
      } else {
        final store = context.read<MoneyStore>();
        final categories = kind == 'income'
            ? store.incomeCategories
            : store.expenseCategories;
        _categoryId = _hasScanDraft || categories.isEmpty
            ? null
            : categories.first.id;
      }
    });
    _ensureSelections();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() => _date = dateOnly(picked));
    }
  }

  Future<void> _pickAccount({required bool to}) async {
    final store = context.read<MoneyStore>();
    final accounts = store.activeAccounts;
    final selected = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => _WalletSheet(
        title: switch (_kind) {
          'income' => 'Terima ke dompet',
          'expense' => 'Bayar dari dompet',
          _ => to ? 'Ke dompet' : 'Dari dompet',
        },
        accounts: accounts,
        selectedId: to ? _toAccountId : _accountId,
        excludedId: to
            ? _accountId
            : _isEditing && _isTransfer
            ? _toAccountId
            : null,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == '__manage__') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ManageAccountsPage()),
      );
      if (!mounted) return;
      final refreshed = context.read<MoneyStore>().activeAccounts;
      setState(() {
        if (_accountId == null ||
            (!_isEditing &&
                !refreshed.any((account) => account.id == _accountId))) {
          _accountId = refreshed.isEmpty ? null : refreshed.first.id;
        }
        if (to &&
            (_toAccountId == null ||
                (!_isEditing &&
                    !refreshed.any((account) => account.id == _toAccountId)))) {
          _toAccountId = refreshed
              .where((account) => account.id != _accountId)
              .firstOrNull
              ?.id;
        }
      });
      return;
    }
    setState(() {
      if (to) {
        _toAccountId = selected;
      } else {
        _accountId = selected;
        if (_isTransfer && _toAccountId == selected) {
          _toAccountId = accounts
              .where((account) => account.id != selected)
              .firstOrNull
              ?.id;
        }
      }
    });
  }

  Future<void> _addCategoryInline() async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty || _addingCategory) return;
    final kind = _kind;
    setState(() => _addingCategory = true);
    try {
      final category = await context.read<MoneyStore>().addCategory(
        name,
        kind,
        iconId: _draftCategoryIconId,
      );
      if (!mounted || _kind != kind || !_creatingCategory) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _categoryId = category.id;
        _creatingCategory = false;
        _draftCategoryIconId = null;
        _categoryError = null;
        _categoryNameController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _categoryScroll.hasClients &&
            _categoryId == category.id) {
          _categoryScroll.jumpTo(_categoryScroll.position.maxScrollExtent);
        }
      });
    } on NameConflictException {
      if (!mounted || _kind != kind || !_creatingCategory) return;
      setState(() => _categoryError = 'Kategori itu sudah ada.');
    } finally {
      if (mounted) setState(() => _addingCategory = false);
    }
  }

  Future<void> _changeCategoryIcon(MoneyCategory category) async {
    final store = context.read<MoneyStore>();
    final choice = await showMoneyIconPicker(
      context,
      iconSet: MoneyIconSet.category,
      value: category.iconId,
      automatic: categoryIconSpec(null, categoryId: category.id),
      categoryKind: category.kind,
    );
    if (!mounted || choice == null || choice.id == category.iconId) return;
    await store.renameCategory(
      category.id,
      category.name,
      iconId: choice.id,
      clearIcon: choice.id == null,
    );
  }

  void _cancelCategory() {
    if (_addingCategory) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _creatingCategory = false;
      _draftCategoryIconId = null;
      _categoryNameController.clear();
      _categoryError = null;
    });
  }

  bool get _canSave {
    final original = widget.transaction;
    final preservingZero = _sameKind && !_hasScanDraft && original?.amount == 0;
    if ((_amount <= 0 && !preservingZero) ||
        _date == null ||
        _scanning ||
        (widget.receiptImage != null && !_manualKindChosen)) {
      return false;
    }
    if (_isTransfer) {
      return _accountId != null &&
          _toAccountId != null &&
          _accountId != _toAccountId;
    }
    final preservingNoCategory =
        _sameKind && !_hasScanDraft && original?.categoryId == null;
    return (_categoryId != null ||
            preservingNoCategory ||
            widget.initialBill != null) &&
        _accountId != null;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final store = context.read<MoneyStore>();
      final settings = context.read<SettingsStore>();
      final note = _noteController.text.trim();
      final transaction = MoneyTransaction(
        id: _entryId,
        amount: _signedAmount,
        kind: _kind,
        categoryId: _isTransfer
            ? (_sameKind ? widget.transaction?.categoryId : null)
            : _categoryId,
        accountId: _accountId!,
        toAccountId: _isTransfer ? _toAccountId : null,
        date: dateKey(_date!),
        time: widget.transaction?.time,
        note: note.isEmpty ? null : note,
        detail: _detail,
        createdAt:
            widget.transaction?.createdAt ??
            DateTime.now().millisecondsSinceEpoch,
      );
      final previous = widget.transaction;
      var delta = balanceDeltaOf(transaction);
      if (previous != null) delta -= balanceDeltaOf(previous);

      if (widget.saveBillPayment case final save?) {
        await save(transaction);
      } else if (_isEditing) {
        await store.updateTransaction(transaction);
      } else {
        await store.addTransaction(transaction);
      }
      final receipt = widget.receiptImage;
      if (receipt != null) {
        try {
          await ReceiptInbox.discard(receipt);
        } catch (_) {
          // Keep a successfully saved transaction even if cleanup needs retry.
          debugPrint('Draf struk belum bisa dihapus.');
        }
      }
      if (delta != 0 && settings.soundEnabled) {
        SoundFx.play(delta > 0 ? settings.soundUp : settings.soundDown);
      }
      if (mounted) Navigator.of(context).pop(transaction.date);
    } on PaydayWriteException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(error.message);
    } catch (_) {
      debugPrint('Simpan transaksi gagal.');
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Gagal menyimpan. Coba lagi.');
    }
  }

  Future<void> _delete() async {
    final transaction = widget.transaction;
    if (transaction == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: EsokMotion.presentation(context),
      builder: (context) => AlertDialog(
        backgroundColor: EsokColors.canvas,
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus permanen.'),
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
    await context.read<MoneyStore>().deleteTransaction(transaction.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _scanReceipt() async {
    if (_scanning || _saving) return;
    final settings = context.read<SettingsStore>();
    final store = context.read<MoneyStore>();
    if (!settings.aiReady) {
      _toast('Isi API key dulu di Setelan → Pindai struk.');
      return;
    }

    var scanning = false;
    try {
      final file = widget.receiptImage ?? await _pickReceipt();
      if (file == null || !mounted) return;
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        sheetAnimationStyle: EsokMotion.presentation(context),
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x5214120E),
        isScrollControlled: true,
        builder: (_) =>
            _ScanConfirmSheet(file: file, shared: widget.receiptImage != null),
      );
      if (proceed != true || !mounted) return;

      scanning = true;
      setState(() => _scanning = true);
      final result = await ReceiptScanner.scan(
        image: file,
        apiKey: settings.aiKey,
        model: settings.aiModel,
        expenseCategories: store.expenseCategories,
        incomeCategories: store.incomeCategories,
      );
      if (!mounted) return;
      if (result.transaksi.isEmpty) {
        _toast('Tidak ada data terbaca. Draf tidak diubah.');
        return;
      }

      ScanTransaction? chosen;
      if (result.transaksi.length == 1) {
        chosen = result.transaksi.first;
      } else {
        chosen = await showModalBottomSheet<ScanTransaction>(
          context: context,
          sheetAnimationStyle: EsokMotion.presentation(context),
          backgroundColor: Colors.transparent,
          barrierColor: const Color(0x5214120E),
          isScrollControlled: true,
          builder: (_) => _ScanRowsSheet(transactions: result.transaksi),
        );
      }
      if (chosen == null || !mounted) return;
      final reviewed = await showModalBottomSheet<ScanReviewChoice>(
        context: context,
        sheetAnimationStyle: EsokMotion.presentation(context),
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x5214120E),
        isScrollControlled: true,
        builder: (_) => ScanReviewSheet(
          scan: chosen!,
          manualKind: _manualKindChosen ? _kind : null,
        ),
      );
      if (reviewed == null || !mounted) return;
      _applyScan(store, reviewed);
    } on ReceiptScanException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('Gagal memindai struk.');
    } finally {
      if (mounted && scanning) setState(() => _scanning = false);
    }
  }

  Future<File?> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      builder: (_) => const _ScanSourceSheet(),
    );
    if (source == null || !mounted) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
  }

  void _applyScan(MoneyStore store, ScanReviewChoice reviewed) {
    final scan = reviewed.scan;
    final newKind = reviewed.kind;
    final pool = newKind == 'income'
        ? store.incomeCategories
        : store.expenseCategories;
    setState(() {
      _kind = newKind;
      _manualKindChosen = true;
      _hasScanDraft = true;
      _amount = scan.nominal ?? 0;
      _categoryId = scan.categoryIdFor(newKind, pool);
      _date = scan.tanggal;
      _noteController.text = _summaryForScan(scan);
      _detail = scan.detailText(numberText);
      _creatingCategory = false;
      _draftCategoryIconId = null;
    });
    _ensureSelections();
    _toast('Draf pindai perlu diperiksa. Simpan hanya setelah cocok.');
  }

  String _summaryForScan(ScanTransaction scan) {
    final pihak = scan.pihak?.trim();
    final catatan = scan.catatan?.trim();
    if (scan.barang.isNotEmpty) {
      return '${pihak ?? 'Hasil pindai'} · ${scan.barang.length} item';
    }
    if (pihak != null && pihak.isNotEmpty) {
      if (catatan != null && catatan.isNotEmpty) return '$pihak · $catatan';
      return pihak;
    }
    if (catatan != null && catatan.isNotEmpty) return catatan;
    return 'Hasil pindai';
  }

  void _showItems() {
    final detail = _detail;
    if (detail == null || detail.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: EsokMotion.presentation(context),
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5214120E),
      isScrollControlled: true,
      builder: (_) => ItemsSheet(detail: detail, total: _amount),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoneyStore>();
    final categories = _kind == 'income'
        ? store.incomeCategories
        : store.expenseCategories;
    final selectedCategory = categories
        .where((category) => category.id == _categoryId)
        .firstOrNull;
    final selectedAccount = _accountId == null
        ? null
        : store.accountById(_accountId!);
    final selectedToAccount = _toAccountId == null
        ? null
        : store.accountById(_toAccountId!);

    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: EsokColors.canvas,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final columns = wide ? 6 : 3;
            const keyHeight = 48.0;
            final keypadHeight = (12 ~/ columns) * (keyHeight + 7) - 7 + 16;
            // Choose the dock's placement once for this viewport, irrespective
            // of insets from Android's keyboard.
            final safeHeight = media.size.height - media.viewPadding.vertical;
            final docked = safeHeight >= keypadHeight + 168;
            final reduceMotion =
                media.reduceMotion ||
                media.disableAnimations ||
                media.accessibleNavigation;
            final dock = _TransactionDock(
              visible: !keyboardOpen,
              reduceMotion: reduceMotion,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _Keypad(
                      key: const ValueKey('transaction-keypad'),
                      onKey: _pressKey,
                      columns: columns,
                      keyHeight: keyHeight,
                    ),
                  ),
                  _BottomActions(
                    canSave: _canSave,
                    saving: _saving,
                    scanning: _scanning,
                    onCancel: () => Navigator.of(context).pop(),
                    onScan: _scanReceipt,
                    onSave: _save,
                  ),
                ],
              ),
            );

            final children = <Widget>[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Center(
                  child: Text(
                    _isEditing ? 'Ubah' : 'Catat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _Segments(
                  selected: widget.receiptImage != null && !_manualKindChosen
                      ? null
                      : _kind,
                  onChanged: _changeKind,
                ),
              ),
              if (_hasScanDraft)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'Draf pindai perlu diperiksa. Kategori adalah saran; '
                    'lengkapi tanggal dan nominal yang kosong sebelum Simpan.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 8),
              if (!_isTransfer &&
                  (widget.receiptImage == null || _manualKindChosen)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _creatingCategory
                      ? _InlineCategory(
                          controller: _categoryNameController,
                          kind: _kind,
                          error: _categoryError,
                          iconId: _draftCategoryIconId,
                          saving: _addingCategory,
                          onIconChanged: (iconId) =>
                              setState(() => _draftCategoryIconId = iconId),
                          onCancel: _cancelCategory,
                          onSave: _addCategoryInline,
                        )
                      : _CategorySection(
                          categories: categories,
                          selected: selectedCategory,
                          historicalLabel:
                              _sameKind &&
                                  !_hasScanDraft &&
                                  selectedCategory == null
                              ? store.categoryName(_categoryId)
                              : null,
                          controller: _categoryScroll,
                          onSelect: (id) => setState(() => _categoryId = id),
                          onEditIcon: _changeCategoryIcon,
                          onNew: () => setState(() {
                            _creatingCategory = true;
                            _draftCategoryIconId = null;
                            _categoryError = null;
                            _categoryNameController.clear();
                          }),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _WalletPill(
                          label: selectedAccount?.name ?? 'Pilih dompet',
                          account: selectedAccount,
                          onTap: () => _pickAccount(to: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: _NoteField(
                          controller: _noteController,
                          detail: _detail,
                          onShowDetail: _showItems,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WalletPill(
                        label: 'Dari ${selectedAccount?.name ?? '—'}',
                        account: selectedAccount,
                        onTap: () => _pickAccount(to: false),
                      ),
                      const SizedBox(height: 8),
                      _WalletPill(
                        label: 'Ke ${selectedToAccount?.name ?? '—'}',
                        account: selectedToAccount,
                        onTap: () => _pickAccount(to: true),
                      ),
                      const SizedBox(height: 8),
                      _NoteField(
                        controller: _noteController,
                        detail: _detail,
                        onShowDetail: _showItems,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: EsokColors.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isTransfer
                              ? 'PINDAH'
                              : (selectedCategory?.name ?? 'JUMLAH')
                                    .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.06,
                            color: EsokColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _hasScanDraft && _amount == 0
                                ? 'Isi nominal'
                                : 'Rp ${numberText(_signedAmount)}',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.02,
                              color: _amount == 0
                                  ? EsokColors.disabled
                                  : EsokColors.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateChip(
                        label: 'Hari ini',
                        selected: _date == today(),
                        onTap: () => setState(() => _date = today()),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _DateChip(
                        label: 'Kemarin',
                        selected:
                            _date == today().subtract(const Duration(days: 1)),
                        onTap: () => setState(
                          () =>
                              _date = today().subtract(const Duration(days: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(
                          color: EsokColors.soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: EsokColors.ink,
                            ),
                            if (_date == null) ...[
                              const SizedBox(width: 6),
                              const Text('Pilih tanggal'),
                            ] else if (_date != today() &&
                                _date !=
                                    today().subtract(
                                      const Duration(days: 1),
                                    )) ...[
                              const SizedBox(width: 6),
                              Text(
                                shortDateTitle(_date!),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: EsokColors.ink,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: EsokColors.lateInk,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Hapus transaksi'),
                  ),
                ),
              const SizedBox(height: 8),
              if (!docked) dock,
            ];

            // Keep the editable scroll view mounted across IME changes so
            // the note and category fields never lose focus.
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    child: Column(children: children),
                  ),
                ),
                if (docked) dock,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanSourceSheet extends StatelessWidget {
  const _ScanSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: EsokColors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Pindai struk',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Foto langsung atau pilih dari galeri',
              style: TextStyle(fontSize: 11, color: EsokColors.muted),
            ),
            const SizedBox(height: 8),
            const _ScanSourceRow(
              icon: Icons.photo_camera_outlined,
              label: 'Kamera',
              source: ImageSource.camera,
            ),
            Divider(height: 1, color: EsokColors.line),
            const _ScanSourceRow(
              icon: Icons.photo_library_outlined,
              label: 'Galeri',
              source: ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanSourceRow extends StatelessWidget {
  const _ScanSourceRow({
    required this.icon,
    required this.label,
    required this.source,
  });

  final IconData icon;
  final String label;
  final ImageSource source;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Icon(icon, size: 19, color: EsokColors.muted),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: EsokColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanConfirmSheet extends StatelessWidget {
  const _ScanConfirmSheet({required this.file, required this.shared});

  final File file;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
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
                  color: EsokColors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Foto siap dipindai',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Foto dikirim ke Gemini setelah kamu menekan Pindai.',
              style: TextStyle(fontSize: 11, color: EsokColors.muted),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 900,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Foto ini sudah tidak tersedia.')),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.auto_awesome, size: 17),
                label: const Text('Pindai dengan Gemini'),
                style: FilledButton.styleFrom(
                  backgroundColor: EsokColors.accent,
                  foregroundColor: EsokColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: EsokColors.muted,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: Text(shared ? 'Nanti saja' : 'Ganti foto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String> onChanged;

  static const _values = ['expense', 'income', 'transfer'];
  static const _labels = ['Keluar', 'Masuk', 'Pindah'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: EsokColors.track,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(_values[i]),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == _values[i]
                        ? EsokColors.canvas
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected == _values[i]
                        ? [
                            BoxShadow(
                              color: EsokColors.ink.withValues(alpha: 0.06),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected == _values[i]
                          ? EsokColors.ink
                          : EsokColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selected,
    required this.historicalLabel,
    required this.controller,
    required this.onSelect,
    required this.onEditIcon,
    required this.onNew,
  });

  final List<MoneyCategory> categories;
  final MoneyCategory? selected;
  final String? historicalLabel;
  final ScrollController controller;
  final ValueChanged<String> onSelect;
  final ValueChanged<MoneyCategory> onEditIcon;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    const gap = 6.0;
    final rowHeight = math.max(
      60.0,
      40 + MediaQuery.textScalerOf(context).scale(11) * 1.35,
    );
    final rows = (categories.length + columns - 1) ~/ columns;
    final height = math.min(
      rows * (rowHeight + gap) - gap,
      rowHeight * 2.5 + gap * 2,
    );
    final action = TextButton.styleFrom(
      foregroundColor: EsokColors.ink,
      minimumSize: const Size(48, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 12),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Kategori',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (selected case final category?)
                    TextButton(
                      onPressed: () => onEditIcon(category),
                      style: action,
                      child: const Text('Ubah ikon'),
                    ),
                  TextButton.icon(
                    onPressed: onNew,
                    style: action,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Baru'),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (historicalLabel case final label?)
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        if (rows == 0 && historicalLabel == null)
          Text(
            'Belum ada kategori.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (rows > 0)
          SizedBox(
            key: const ValueKey('transaction-categories'),
            height: height,
            child: GridView.builder(
              controller: controller,
              primary: false,
              padding: EdgeInsets.zero,
              itemCount: categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: rowHeight,
              ),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryTile(
                  onTap: () => onSelect(category.id),
                  selected: category.id == selected?.id,
                  icon: CategoryIconView(category: category, size: 20),
                  label: category.name,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.onTap,
    required this.selected,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final bool selected;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          decoration: BoxDecoration(
            color: selected ? EsokColors.canvas : EsokColors.soft,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? EsokColors.ink : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? EsokColors.ink : EsokColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineCategory extends StatelessWidget {
  const _InlineCategory({
    required this.controller,
    required this.kind,
    required this.error,
    required this.iconId,
    required this.saving,
    required this.onIconChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController controller;
  final String kind;
  final String? error;
  final String? iconId;
  final bool saving;
  final ValueChanged<String?> onIconChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      enabled: !saving,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSave(),
      style: TextStyle(fontSize: 14, color: EsokColors.ink),
      decoration: InputDecoration(
        hintText: 'Nama kategori baru',
        hintStyle: TextStyle(fontSize: 14, color: EsokColors.muted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 13,
        ),
        filled: true,
        fillColor: EsokColors.soft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: EsokColors.ink, width: 1.2),
        ),
      ),
    );
    final cancel = TextButton(
      onPressed: saving ? null : onCancel,
      style: TextButton.styleFrom(
        foregroundColor: EsokColors.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: const Text('Batal'),
    );
    final save = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextButton(
        onPressed: saving || value.text.trim().isEmpty ? null : onSave,
        style: TextButton.styleFrom(
          foregroundColor: EsokColors.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: const Text('Tambah'),
      ),
    );
    final icon = MoneyIconField(
      iconSet: MoneyIconSet.category,
      categoryKind: kind,
      value: iconId,
      automatic: categoryIconSpec(null),
      onChanged: onIconChanged,
      compact: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.textScalerOf(context).scale(14) <= 19)
          Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: 8),
              icon,
            ],
          )
        else ...[
          field,
          Align(alignment: AlignmentDirectional.centerStart, child: icon),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 0, 2),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(fontSize: 12, color: EsokColors.lateInk),
              ),
            ),
          ),
        Wrap(alignment: WrapAlignment.end, children: [cancel, save]),
      ],
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.label, required this.onTap, this.account});

  final String label;
  final VoidCallback onTap;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: EsokColors.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (account case final selected?)
              WalletIconView(account: selected, size: 16)
            else
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: EsokColors.muted,
              ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: EsokColors.ink),
              ),
            ),
            Icon(Icons.chevron_right, size: 15, color: EsokColors.muted),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  const _NoteField({
    required this.controller,
    required this.detail,
    required this.onShowDetail,
  });

  final TextEditingController controller;
  final String? detail;
  final VoidCallback onShowDetail;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final hasDetail = widget.detail != null && widget.detail!.isNotEmpty;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: EsokColors.soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? EsokColors.ink : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _focusNode.unfocus(),
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 13.5, color: EsokColors.ink),
              decoration: InputDecoration(
                hintText: 'Catatan',
                hintStyle: TextStyle(fontSize: 13.5, color: EsokColors.muted),
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (hasDetail)
            GestureDetector(
              onTap: widget.onShowDetail,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: EsokColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected ? EsokColors.ink : EsokColors.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? EsokColors.canvas : EsokColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    super.key,
    required this.onKey,
    required this.columns,
    required this.keyHeight,
  });

  final ValueChanged<String> onKey;
  final int columns;
  final double keyHeight;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '000',
    '0',
    'back',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < _keys.length ~/ columns; row++) ...[
          if (row > 0) const SizedBox(height: 7),
          Row(
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) const SizedBox(width: 7),
                Expanded(
                  child: _KeyButton(
                    value: _keys[row * columns + col],
                    height: keyHeight,
                    onTap: onKey,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _TransactionDock extends StatefulWidget {
  const _TransactionDock({
    required this.visible,
    required this.reduceMotion,
    required this.child,
  });

  final bool visible;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_TransactionDock> createState() => _TransactionDockState();
}

class _TransactionDockState extends State<_TransactionDock>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: widget.visible ? 1 : 0,
  );
  late final _progress = _reveal.drive(CurveTween(curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant _TransactionDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible || widget.reduceMotion) {
      _reveal.value = widget.visible ? 1 : 0;
    } else if (!oldWidget.visible) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    alignment: Alignment.bottomCenter,
    sizeFactor: _progress,
    child: FadeTransition(
      opacity: _progress,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: IgnorePointer(ignoring: !widget.visible, child: widget.child),
      ),
    ),
  );
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.value,
    required this.height,
    required this.onTap,
  });

  final String value;
  final double height;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isBack = value == 'back';
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: EsokColors.soft,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: isBack
            ? Icon(Icons.backspace_outlined, size: 19, color: EsokColors.muted)
            : Text(
                value,
                style: TextStyle(
                  fontSize: value == '000' ? 13 : 19,
                  fontWeight: FontWeight.w500,
                  color: value == '000' ? EsokColors.muted : EsokColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.canSave,
    required this.saving,
    required this.scanning,
    required this.onCancel,
    required this.onScan,
    required this.onSave,
  });

  final bool canSave;
  final bool saving;
  final bool scanning;
  final VoidCallback onCancel;
  final VoidCallback onScan;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(11),
    );
    final compactIcon = MediaQuery.textScalerOf(context).scale(13) <= 17;
    final padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 8);
    const minimum = Size(0, 48);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: TextButton(
                onPressed: scanning || saving ? null : onScan,
                style: TextButton.styleFrom(
                  foregroundColor: EsokColors.ink,
                  disabledForegroundColor: EsokColors.muted,
                  minimumSize: minimum,
                  padding: padding,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scanning) ...[
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 5),
                    ] else if (compactIcon) ...[
                      const Icon(Icons.document_scanner_outlined, size: 16),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Semantics(
                        liveRegion: scanning,
                        child: Text(
                          scanning ? 'Memindai…' : 'Pindai struk',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EsokColors.ink,
                  minimumSize: minimum,
                  padding: padding,
                  side: BorderSide(color: EsokColors.lineStrong),
                  shape: shape,
                ),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 8,
              child: FilledButton(
                onPressed: canSave && !saving ? onSave : null,
                style: FilledButton.styleFrom(
                  backgroundColor: EsokColors.accent,
                  foregroundColor: EsokColors.onAccent,
                  disabledBackgroundColor: EsokColors.soft,
                  disabledForegroundColor: EsokColors.disabled,
                  minimumSize: minimum,
                  padding: padding,
                  shape: shape,
                ),
                child: Text(saving ? 'Menyimpan…' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanRowsSheet extends StatefulWidget {
  const _ScanRowsSheet({required this.transactions});

  final List<ScanTransaction> transactions;

  @override
  State<_ScanRowsSheet> createState() => _ScanRowsSheetState();
}

class _ScanRowsSheetState extends State<_ScanRowsSheet> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
                  color: EsokColors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Pilih transaksi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gambar berisi ${widget.transactions.length} baris. Pilih satu.',
              style: TextStyle(fontSize: 11.5, color: EsokColors.muted),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.transactions.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: EsokColors.line),
                itemBuilder: (context, index) {
                  final scan = widget.transactions[index];
                  final selected = index == _selected;
                  final incoming = scan.arah == 'masuk';
                  return GestureDetector(
                    onTap: () => setState(() => _selected = index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: selected
                                ? EsokColors.accent
                                : EsokColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scan.pihak ??
                                      scan.catatan ??
                                      'Transaksi ${index + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: EsokColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (scan.tanggal != null)
                                      shortDateTitle(scan.tanggal!),
                                    if (scan.tanggal == null)
                                      'Tanggal belum terbaca',
                                    scan.arah == null
                                        ? 'Arah perlu diperiksa'
                                        : incoming
                                        ? 'Masuk'
                                        : 'Keluar',
                                    if (scan.kategori != null) scan.kategori!,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: EsokColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            scan.nominal == null
                                ? 'Nominal belum terbaca'
                                : '${scan.arah == null
                                          ? ''
                                          : incoming
                                          ? '+'
                                          : '−'}'
                                      '${numberText(scan.nominal!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: incoming
                                  ? EsokColors.positive
                                  : EsokColors.negative,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: widget.transactions.isEmpty
                    ? null
                    : () =>
                          Navigator.of(context)
                              .pop(widget.transactions[_selected]),
                style: FilledButton.styleFrom(
                  backgroundColor: EsokColors.accent,
                  foregroundColor: EsokColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text('Pakai baris terpilih'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSheet extends StatelessWidget {
  const _WalletSheet({
    required this.title,
    required this.accounts,
    required this.selectedId,
    this.excludedId,
  });

  final String title;
  final List<Account> accounts;
  final String? selectedId;
  final String? excludedId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
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
                  color: EsokColors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EsokColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final account in accounts)
              if (account.id != excludedId)
                Semantics(
                  selected: selectedId == account.id,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(account.id),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          WalletIconView(account: account, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              account.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: EsokColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              accountTypeLabel(account.type),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 11,
                                color: EsokColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 18,
                            child: selectedId == account.id
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: EsokColors.ink,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const Divider(),
            TextButton(
              onPressed: () => Navigator.of(context).pop('__manage__'),
              style: TextButton.styleFrom(
                foregroundColor: EsokColors.accent,
                alignment: Alignment.centerLeft,
              ),
              child: const Text('Kelola dompet'),
            ),
          ],
        ),
      ),
    );
  }
}
