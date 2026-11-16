import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class EsokFloatingAddButton extends StatelessWidget {
  const EsokFloatingAddButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.bottomLift,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final double bottomLift;

  // Leave room to scroll the last row past both the capsule and the FAB.
  // 56 is the standard FAB size; the other space is its margins.
  static double scrollBottomOf(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 56 + kFloatingActionButtonMargin * 2;

  // Read the outer Scaffold's measured inset before the inner Scaffold strips
  // MediaQuery padding from its FAB slot.
  static double liftOf(BuildContext context) => math.max(
    0.0,
    MediaQuery.paddingOf(context).bottom -
        MediaQuery.viewPaddingOf(context).bottom,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomLift),
      child: FloatingActionButton(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        tooltip: tooltip,
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}
