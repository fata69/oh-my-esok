import 'package:material_ui/material_ui.dart';

import 'glass_controls.dart';
import 'motion.dart';
import 'theme.dart';

class EsokSheetAction<T> {
  const EsokSheetAction(
    this.value,
    this.label,
    this.icon, {
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
  final bool enabled;
}

Future<T?> showEsokActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<EsokSheetAction<T>> actions,
  String? footer,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: EsokColors.scrim,
  sheetAnimationStyle: EsokMotion.presentation(context),
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => EsokSheetPanel(
    title: title,
    floating: true,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      shrinkWrap: true,
      children: [
        for (final action in actions) ...[
          if (action.destructive) const Divider(indent: 12, endIndent: 12),
          _ActionRow(
            label: action.label,
            icon: action.icon,
            onSelected: action.enabled
                ? () => Navigator.pop(context, action.value)
                : null,
          ),
        ],
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(footer, style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    ),
  ),
);

class EsokSheetPanel extends StatelessWidget {
  const EsokSheetPanel({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.floating = false,
  });

  final String title;
  final Widget body;
  final Widget? subtitle;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final radius = floating
        ? BorderRadius.circular(24)
        : EsokColors.sheetRadius;
    final content = Material(
      color: floating ? Colors.transparent : colors.canvas,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: subtitle!,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      visualDensity: VisualDensity.standard,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: floating ? 8 : 0),
      child: floating
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: EsokGlass(radius: radius, child: content),
            )
          : content,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    final enabled = onSelected != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: enabled ? colors.ink : colors.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: enabled ? colors.ink : colors.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
