import 'package:material_ui/material_ui.dart';

import '../util/format.dart';
import 'action_sheet.dart';

class ItemsSheet extends StatelessWidget {
  const ItemsSheet({super.key, required this.detail, this.total});

  final String detail;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final formattedTotal = total == null ? null : rupiahText(total!);
    final lines = detail
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return EsokSheetPanel(
      title: 'Rincian barang',
      subtitle: formattedTotal == null
          ? null
          : Text(
              'Total $formattedTotal',
              style: text.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        shrinkWrap: true,
        itemCount: lines.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(lines[index], style: text.bodyLarge),
        ),
      ),
    );
  }
}
