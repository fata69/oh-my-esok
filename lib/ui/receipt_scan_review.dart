import 'package:material_ui/material_ui.dart';

import '../ai/receipt_scanner.dart';
import '../util/format.dart';
import 'theme.dart';

class ScanReviewChoice {
  const ScanReviewChoice({required this.scan, required this.kind});

  final ScanTransaction scan;
  final String kind;
}

// No store or database access: dismissing this sheet cannot change a draft.
class ScanReviewSheet extends StatefulWidget {
  const ScanReviewSheet({super.key, required this.scan, this.manualKind});

  final ScanTransaction scan;
  final String? manualKind;

  @override
  State<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends State<ScanReviewSheet> {
  String? _kind;

  @override
  void initState() {
    super.initState();
    _kind = widget.manualKind ?? widget.scan.kind;
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final amount = scan.nominal;
    final date = scan.tanggal;
    final detail = scan.detailText(numberText);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Periksa hasil pindai',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hasil AI bisa salah. Belum ada data yang disimpan. '
                'Cocokkan dengan gambar sebelum memasukkan ke draf.',
              ),
              const SizedBox(height: 16),
              Text(amount == null
                  ? 'Nominal belum terbaca atau ambigu — isi di draf'
                  : 'Nominal: Rp ${numberText(amount)}'),
              if (amount != null && scan.nominalAsli != null)
                Text('Teks nominal: ${scan.nominalAsli}'),
              const SizedBox(height: 8),
              Text(date == null
                  ? 'Tanggal belum terbaca — pilih di draf'
                  : 'Tanggal: ${date.year}-${date.month.toString().padLeft(2, '0')}-'
                        '${date.day.toString().padLeft(2, '0')}'),
              if (scan.pihak != null) Text(scan.pihak!),
              if (scan.catatan != null) Text(scan.catatan!),
              const SizedBox(height: 12),
              Text(scan.kind == null
                  ? 'Arah belum pasti — periksa pilihan manual'
                  : 'Arah terbaca: ${scan.kind == 'income' ? 'Masuk' : 'Keluar'}'),
              if (widget.manualKind != null)
                const Text('Pilihan manual dipertahankan; periksa sebelum lanjut.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const {
                    'expense': 'Keluar',
                    'income': 'Masuk',
                    'transfer': 'Pindah',
                  }.entries)
                    ChoiceChip(
                      key: ValueKey('scan-kind-${entry.key}'),
                      label: Text(entry.value),
                      selected: _kind == entry.key,
                      onSelected: (_) => setState(() => _kind = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(scan.kind == _kind && scan.kategori != null
                  ? 'Saran kategori: ${scan.kategori} — periksa di draf'
                  : 'Kategori belum dipilih — pilih di draf'),
              if (detail != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Transkripsi barang',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(detail),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('scan-apply'),
                onPressed: _kind == null
                    ? null
                    : () => Navigator.of(context).pop(
                        ScanReviewChoice(scan: scan, kind: _kind!),
                      ),
                child: const Text('Masukkan ke draf'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
