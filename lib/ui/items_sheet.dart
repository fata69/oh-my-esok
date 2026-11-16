import 'package:material_ui/material_ui.dart';

import '../util/format.dart';
import 'theme.dart';

class ItemsSheet extends StatelessWidget {
  const ItemsSheet({
    super.key,
    required this.detail,
    this.total,
  });

  final String detail;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final lines = detail
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rincian barang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                    ),
                  ),
                ),
                if (total != null)
                  Text(
                    'Rp ${numberText(total!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EsokColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lines.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: EsokColors.line),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    lines[index],
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: EsokColors.inkSoft,
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
