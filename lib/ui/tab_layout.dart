import 'package:material_ui/material_ui.dart';

import 'chevron.dart';
import 'theme.dart';

class EsokTabLayout extends StatelessWidget {
  const EsokTabLayout({super.key, this.headerAction, required this.child});

  static const gutter = 24.0;

  // The shell's extended body reports the full, measured navigation height here.
  // Let the list scroll behind it, with enough space to reveal the final row.
  static double scrollBottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 16;

  final Widget? headerAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              6,
              headerAction == null ? gutter : 12,
              0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Oh My Esok',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  ?headerAction,
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class EsokPeriodHeader extends StatelessWidget {
  const EsokPeriodHeader({
    super.key,
    required this.title,
    required this.previousLabel,
    required this.nextLabel,
    this.onPrevious,
    required this.onNext,
    this.caption,
    this.detail,
    this.onSelect,
  });

  final String title;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final String? caption;
  final String? detail;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final period = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null) ...[
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EsokTabLayout.gutter,
        8,
        EsokTabLayout.gutter,
        8,
      ),
      child: Row(
        children: [
          _PeriodArrow(label: previousLabel, left: true, onTap: onPrevious),
          Expanded(
            child: onSelect == null
                ? period
                : InkWell(
                    onTap: onSelect,
                    borderRadius: BorderRadius.circular(8),
                    child: period,
                  ),
          ),
          _PeriodArrow(label: nextLabel, left: false, onTap: onNext),
        ],
      ),
    );
  }
}

class _PeriodArrow extends StatelessWidget {
  const _PeriodArrow({
    required this.label,
    required this.left,
    required this.onTap,
  });

  final String label;
  final bool left;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Opacity(
        opacity: onTap == null ? 0.32 : 1,
        child: EsokChevron(left: left, size: 16),
      ),
    );
  }
}

class EsokEntryButton extends StatelessWidget {
  const EsokEntryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = EsokColors.of(context);
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: colors.ink,
        foregroundColor: colors.canvas,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }
}
