import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.primary = false,
  });

  final String label;
  final List<double> values;
  final Color color;

  /// Primary series: thicker line, filled dots and a gradient area underneath.
  final bool primary;
}

/// Small dependency-free line chart with a legend.
class UsageLineChart extends StatelessWidget {
  const UsageLineChart({
    super.key,
    required this.xLabels,
    required this.series,
    this.maxY = 3000,
    this.stepY = 1000,
    this.height = 260,
  });

  final List<String> xLabels;
  final List<ChartSeries> series;
  final double maxY;
  final double stepY;
  final double height;

  bool get _hasData =>
      xLabels.isNotEmpty && series.any((s) => s.values.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final labelStyle = DefaultTextStyle.of(context).style
        .copyWith(color: AppColors.hint, fontSize: 12);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.primary ? s.color : Colors.white,
                      border: Border.all(color: s.color, width: 2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: const TextStyle(color: AppColors.navy, fontSize: 14),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              xLabels: xLabels,
              series: series,
              maxY: maxY,
              stepY: stepY,
              labelStyle: labelStyle,
            ),
            child: _hasData
                ? null
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 44,
                          color: Color(0xFFB7CBEE),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'ยังไม่มีข้อมูล',
                          style: TextStyle(color: AppColors.hint, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.xLabels,
    required this.series,
    required this.maxY,
    required this.stepY,
    required this.labelStyle,
  });

  final List<String> xLabels;
  final List<ChartSeries> series;
  final double maxY;
  final double stepY;
  final TextStyle labelStyle;

  static const _leftPad = 36.0;
  static const _bottomPad = 30.0;
  static const _topPad = 8.0;
  static const _inset = 20.0;

  TextPainter _text(String s) => TextPainter(
    text: TextSpan(text: s, style: labelStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTRB(
      _leftPad,
      _topPad,
      size.width,
      size.height - _bottomPad,
    );
    final grid = Paint()
      ..color = const Color(0xFFE3EAF6)
      ..strokeWidth = 1;

    final hasData =
        xLabels.isNotEmpty && series.any((s) => s.values.isNotEmpty);
    // Empty state: leave the area clean so the "no data" message reads well.
    if (!hasData) return;

    // Horizontal grid + y labels.
    for (var v = 0.0; v <= maxY; v += stepY) {
      final y = chart.bottom - v / maxY * chart.height;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final tp = _text(_fmt(v));
      tp.paint(canvas, Offset(chart.left - tp.width - 10, y - tp.height / 2));
    }

    final n = xLabels.length;
    double xAt(int i) =>
        chart.left +
        _inset +
        (n == 1 ? 0 : i * (chart.width - _inset * 2) / (n - 1));
    double yAt(double v) =>
        chart.bottom - (v.clamp(0, maxY) / maxY) * chart.height;

    // X labels + faint vertical guides.
    for (var i = 0; i < n; i++) {
      final x = xAt(i);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        grid..color = const Color(0xFFF0F4FB),
      );
      final tp = _text(xLabels[i]);
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 10));
    }

    // Draw secondary series first so the primary sits on top.
    final ordered = [
      ...series.where((s) => !s.primary),
      ...series.where((s) => s.primary),
    ];
    for (final s in ordered) {
      final pts = [
        for (var i = 0; i < s.values.length && i < n; i++)
          Offset(xAt(i), yAt(s.values[i])),
      ];
      if (pts.isEmpty) continue;

      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final p0 = pts[i - 1];
        final p1 = pts[i];
        final mid = (p1.dx - p0.dx) / 2;
        line.cubicTo(p0.dx + mid, p0.dy, p1.dx - mid, p1.dy, p1.dx, p1.dy);
      }

      if (s.primary) {
        final area = Path.from(line)
          ..lineTo(pts.last.dx, chart.bottom)
          ..lineTo(pts.first.dx, chart.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.18),
                s.color.withValues(alpha: 0),
              ],
            ).createShader(chart),
        );
      }

      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.primary ? 3 : 2.2
          ..strokeCap = StrokeCap.round,
      );

      for (final p in pts) {
        canvas.drawCircle(
          p,
          5.5,
          Paint()..color = s.primary ? Colors.white : Colors.white,
        );
        canvas.drawCircle(
          p,
          s.primary ? 4.5 : 4,
          Paint()
            ..color = s.color
            ..style = s.primary ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.series != series || old.xLabels != xLabels || old.maxY != maxY;
}
