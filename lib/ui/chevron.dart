import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class EsokChevron extends StatelessWidget {
  const EsokChevron({
    super.key,
    required this.left,
    this.color,
    this.size = 18,
  });

  final bool left;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChevronPainter(
        left: left,
        color: color ?? EsokColors.ink,
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.left, required this.color});

  final bool left;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path();
    if (left) {
      path.moveTo(w * 0.62, h * 0.18);
      path.lineTo(w * 0.33, h * 0.5);
      path.lineTo(w * 0.62, h * 0.82);
    } else {
      path.moveTo(w * 0.38, h * 0.18);
      path.lineTo(w * 0.67, h * 0.5);
      path.lineTo(w * 0.38, h * 0.82);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.left != left || oldDelegate.color != color;
}
