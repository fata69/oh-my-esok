import 'package:material_ui/material_ui.dart';

import 'glass_controls.dart';
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
        compact ? 4 : 10,
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
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
      child: Row(
        children: [
          Text(
            'AGENDA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          if (progress case final label?)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            )
          else
            const Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: EsokSkeletonBlock(width: 82, height: 8),
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
