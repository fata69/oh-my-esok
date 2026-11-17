import 'package:material_ui/material_ui.dart';

import 'money_icon_catalog.dart';
import 'theme.dart';

typedef _IconChoice = ({String? id});

/// A compact field that keeps the catalog out of the form until requested.
class MoneyIconField extends StatelessWidget {
  const MoneyIconField({
    super.key,
    required this.iconSet,
    required this.value,
    required this.automatic,
    required this.onChanged,
  });

  final MoneyIconSet iconSet;
  final String? value;
  final MoneyIconSpec automatic;
  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final palette = EsokColors.of(context);
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<_IconChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.canvas,
      barrierColor: EsokColors.scrim,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoneyIconPickerSheet(
        iconSet: iconSet,
        value: value,
        automatic: automatic,
      ),
    );
    if (choice != null && context.mounted) onChanged(choice.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = EsokColors.of(context);
    final current = iconSet.find(value);
    final label = current?.label ?? 'Otomatis';
    return Semantics(
      label: 'Ikon',
      value: label,
      child: TextButton(
        onPressed: () => _open(context),
        style: TextButton.styleFrom(
          foregroundColor: palette.ink,
          alignment: AlignmentDirectional.centerStart,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: ExcludeSemantics(
          child: Row(
            children: [
              MoneyIconGlyph(spec: current ?? automatic, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ikon · $label',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyIconPickerSheet extends StatelessWidget {
  const _MoneyIconPickerSheet({
    required this.iconSet,
    required this.value,
    required this.automatic,
  });

  final MoneyIconSet iconSet;
  final String? value;
  final MoneyIconSpec automatic;

  @override
  Widget build(BuildContext context) {
    final palette = EsokColors.of(context);
    final current = iconSet.find(value);
    final title = iconSet == MoneyIconSet.category
        ? 'Ikon kategori'
        : 'Ikon sumber dana';
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    final textSize = MediaQuery.textScalerOf(context).scale(13);
                    final minWidth = textSize > 17 ? 164.0 : 108.0;
                    final count = ((constraints.maxWidth + gap) / minWidth)
                        .floor()
                        .clamp(1, 3);
                    final width =
                        (constraints.maxWidth - gap * (count - 1)) / count;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final entry in <MoneyIconSpec?>[
                          null,
                          ...iconSet.entries,
                        ])
                          SizedBox(
                            width: width,
                            child: _MoneyIconOption(
                              spec: entry ?? automatic,
                              label: entry?.label ?? 'Otomatis',
                              selected: entry?.id == current?.id,
                              onTap: () => Navigator.pop<_IconChoice>(context, (
                                id: entry?.id,
                              )),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyIconOption extends StatelessWidget {
  const _MoneyIconOption({
    required this.spec,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final MoneyIconSpec spec;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = EsokColors.of(context);
    return Semantics(
      selected: selected,
      child: Stack(
        children: [
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.ink,
              backgroundColor: selected ? palette.control : null,
              side: BorderSide(
                color: selected ? palette.outline : palette.line,
              ),
              minimumSize: const Size(double.infinity, 66),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoneyIconGlyph(spec: spec, size: 22),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
          if (selected)
            PositionedDirectional(
              end: 6,
              top: 5,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Icon(Icons.check, size: 14, color: palette.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
