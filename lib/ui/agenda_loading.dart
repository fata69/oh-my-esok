import 'package:material_ui/material_ui.dart';

import 'motion.dart';
import 'tab_layout.dart';
import 'theme.dart';

class DaySectionSwitch extends StatelessWidget {
  const DaySectionSwitch({super.key, this.notes = false, this.onChanged});

  final bool notes;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EsokTabLayout.gutter),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                for (final (isNotes, label) in [
                  (false, 'Agenda'),
                  (true, 'Catatan'),
                ])
                  Expanded(
                    child: Semantics(
                      selected: isNotes == notes,
                      child: TextButton(
                        onPressed: onChanged == null
                            ? null
                            : () => onChanged!(isNotes),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: isNotes == notes
                              ? colors.ink
                              : colors.muted,
                          disabledForegroundColor: isNotes == notes
                              ? colors.ink
                              : colors.muted,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: TextStyle(
                            fontWeight: isNotes == notes
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        child: Text(label, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedAlign(
                  duration: EsokMotion.reduced(context)
                      ? Duration.zero
                      : EsokMotion.enter,
                  curve: EsokMotion.settle,
                  alignment: notes
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft,
                  child: FractionallySizedBox(
                    widthFactor: .5,
                    child: Center(
                      heightFactor: 1,
                      child: Container(
                        width: 38,
                        height: 2,
                        decoration: BoxDecoration(
                          color: colors.ink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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

class AgendaHeading extends StatelessWidget {
  const AgendaHeading({super.key, this.progress, this.onCloseDay});

  final String? progress;
  final VoidCallback? onCloseDay;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (progress case final label?)
        Text(label, style: Theme.of(context).textTheme.bodyMedium)
      else
        const EsokSkeletonBlock(width: 87, height: 8),
      TextButton.icon(
        onPressed: onCloseDay,
        style: TextButton.styleFrom(
          foregroundColor: EsokColors.of(context).ink,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.fact_check_outlined, size: 16),
        label: const Text('Tutup hari'),
      ),
    ],
  );
}

class AgendaLoading extends StatelessWidget {
  const AgendaLoading({super.key, this.label = 'Memuat agenda'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          EsokTabLayout.gutter,
          4,
          EsokTabLayout.gutter,
          EsokTabLayout.scrollBottomOf(context),
        ),
        children: [
          const AgendaHeading(),
          for (final (index, width) in [132.0, 154.0, 115.0].indexed) ...[
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(
                    width: 48,
                    child: Center(
                      child: EsokSkeletonBlock(
                        width: 22,
                        height: 22,
                        radius: 11,
                      ),
                    ),
                  ),
                  Flexible(child: EsokSkeletonBlock(width: width, height: 11)),
                ],
              ),
            ),
            if (index < 2) const Divider(height: 1, indent: 48, endIndent: 12),
          ],
          const SizedBox(height: 22),
          DecoratedBox(
            decoration: BoxDecoration(
              color: EsokColors.of(context).soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: scale.scale(12) * 1.4 + 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: EsokSkeletonBlock(
                        width: 152,
                        height: 8,
                        color: EsokColors.of(context).line,
                      ),
                    ),
                    const SizedBox(width: 10),
                    EsokSkeletonBlock(
                      width: 36,
                      height: 8,
                      color: EsokColors.of(context).line,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
