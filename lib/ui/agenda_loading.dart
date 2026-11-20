import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:material_ui/material_ui.dart';

import 'glass_controls.dart';
import 'motion.dart';
import 'tab_layout.dart';
import 'theme.dart';

class DaySectionSwitch extends StatelessWidget {
  const DaySectionSwitch({super.key, this.notes = false, this.onChanged});

  final bool notes;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 480;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        EsokTabLayout.gutter,
        0,
        EsokTabLayout.gutter,
        compact ? 2 : 6,
      ),
      child: EsokSegmentedControl<bool>(
        value: notes,
        onChanged: (value) => onChanged?.call(value),
        segments: const [(false, 'Agenda'), (true, 'Catatan')],
      ),
    );
  }
}

class AgendaHeading extends StatelessWidget {
  const AgendaHeading({super.key, this.progress, this.onCloseDay});

  final String? progress;
  final VoidCallback? onCloseDay;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (progress case final label?)
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          else
            const EsokSkeletonBlock(width: 87, height: 8),
          ApplePressable(
            child: TextButton.icon(
              onPressed: onCloseDay,
              style: TextButton.styleFrom(
                foregroundColor: colors.tint,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(CupertinoIcons.moon, size: 15),
              label: const Text('Tutup hari'),
            ),
          ),
        ],
      ),
    );
  }
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
          EsokContentGroup(
            children: [
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
                      Flexible(
                        child: EsokSkeletonBlock(
                          width: width,
                          height: 11,
                          radius: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < 2)
                  const Divider(height: 1, indent: 48, endIndent: 12),
              ],
            ],
          ),
          const SizedBox(height: 18),
          EsokContentGroup(
            children: [
              Padding(
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
                          color: EsokColors.of(context).control,
                        ),
                      ),
                      const SizedBox(width: 10),
                      EsokSkeletonBlock(
                        width: 36,
                        height: 8,
                        color: EsokColors.of(context).control,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
