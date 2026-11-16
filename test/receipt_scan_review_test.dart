import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/ai/receipt_scanner.dart';
import 'package:jadwal/ui/receipt_scan_review.dart';
import 'package:material_ui/material_ui.dart';

const _unknownDirection = ScanTransaction(
  nominal: 25000, arah: null, barang: [],
);

void main() {
  Future<void> openReview(
    WidgetTester tester, {
    required ScanTransaction scan,
    String? manualKind,
    required void Function(ScanReviewChoice?) onClose,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(body: TextButton(
        onPressed: () async {
          final result = await showModalBottomSheet<ScanReviewChoice>(
            context: context, isScrollControlled: true,
            builder: (_) => ScanReviewSheet(scan: scan, manualKind: manualKind),
          );
          onClose(result);
        },
        child: const Text('Pindai'),
      ));
    })));
    await tester.tap(find.text('Pindai'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel keeps the caller draft unchanged', (tester) async {
    Object? draft = 'existing draft';
    await openReview(
      tester, scan: _unknownDirection, manualKind: 'income',
      onClose: (result) { if (result != null) draft = result; },
    );
    expect(find.text('Periksa hasil pindai'), findsOneWidget);
    expect(draft, 'existing draft');
    await tester.ensureVisible(find.text('Batal'));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(draft, 'existing draft');
  });

  testWidgets('manual Pindah survives uncertain scan direction', (tester) async {
    ScanReviewChoice? result;
    await openReview(
      tester, scan: _unknownDirection, manualKind: 'transfer',
      onClose: (value) => result = value,
    );
    expect(tester.widget<ChoiceChip>(find.byKey(
      const ValueKey('scan-kind-transfer'),
    )).selected, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('scan-apply')));
    await tester.tap(find.byKey(const ValueKey('scan-apply')));
    await tester.pumpAndSettle();
    expect(result?.kind, 'transfer');
    expect(result?.scan.tanggal, isNull);
  });

  testWidgets('unknown direction requires an explicit choice', (tester) async {
    ScanReviewChoice? result;
    await openReview(
      tester, scan: _unknownDirection, onClose: (value) => result = value,
    );
    expect(tester.widget<FilledButton>(find.byKey(
      const ValueKey('scan-apply'),
    )).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('scan-kind-income')));
    await tester.ensureVisible(find.byKey(const ValueKey('scan-apply')));
    await tester.tap(find.byKey(const ValueKey('scan-apply')));
    await tester.pumpAndSettle();
    expect(result?.kind, 'income');
  });
}
