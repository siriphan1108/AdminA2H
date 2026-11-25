import 'package:flutter/material.dart';

/// A2 PROPERTY logo: three towers made of stacked rounded bars + wordmark.
class A2Logo extends StatelessWidget {
  const A2Logo({
    super.key,
    required this.color,
    this.width = 120,
    this.showText = true,
  });

  final Color color;
  final double width;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(width, width * 0.62),
          painter: _TowersPainter(color),
        ),
        if (showText) ...[
          SizedBox(height: width * 0.06),
          Text(
            'A2 PROPERTY',
            style: TextStyle(
              color: color,
              fontSize: width * 0.17,
              fontWeight: FontWeight.w700,
              letterSpacing: width * 0.012,
            ),
          ),
        ],
      ],
    );
  }
}

class _TowersPainter extends CustomPainter {
  _TowersPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    // (left, width, heightFactor)
    final towers = [
      (w * 0.10, w * 0.24, 0.66),
      (w * 0.36, w * 0.28, 1.00),
      (w * 0.66, w * 0.24, 0.80),
    ];
    const barCount = 11;
    final pitch = h / barCount;
    final barH = pitch * 0.62;

    for (final (left, tw, f) in towers) {
      final bars = (barCount * f).round();
      for (var i = 0; i < bars; i++) {
        final top = h - (i + 1) * pitch + (pitch - barH);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, tw, barH),
          Radius.circular(barH / 2),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TowersPainter old) => old.color != color;
}
