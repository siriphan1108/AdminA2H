import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Overlays drawn on top of the background photo: a blue tint on the left
/// (so the white text stays readable), a light frosted panel on the right with
/// a curved edge, and a blue swoosh along the bottom.
class LoginBackgroundPainter extends CustomPainter {
  LoginBackgroundPainter({required this.split});

  /// Wide layout: left blue tint + right light panel. Narrow: tint everything.
  final bool split;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;

    // Blue tint, strong at the top (behind the text), fading towards the
    // bottom so the buildings and water show through.
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.navy.withValues(alpha: split ? 0.72 : 0.80),
            AppColors.primary.withValues(alpha: split ? 0.35 : 0.55),
            AppColors.primary.withValues(alpha: split ? 0.10 : 0.35),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(full),
    );

    if (split) {
      // Soft blue band following the curve.
      final band = Path()
        ..moveTo(w * 0.55, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(w * 0.46, h)
        ..cubicTo(w * 0.56, h * 0.7, w * 0.49, h * 0.35, w * 0.55, 0)
        ..close();
      canvas.drawPath(
        band,
        Paint()..color = const Color(0xFFBFD6FA).withValues(alpha: 0.45),
      );

      // Light frosted right panel.
      final light = Path()
        ..moveTo(w * 0.60, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(w * 0.51, h)
        ..cubicTo(w * 0.61, h * 0.7, w * 0.54, h * 0.35, w * 0.60, 0)
        ..close();
      canvas.drawPath(
        light,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF4F8FF).withValues(alpha: 0.92),
              AppColors.skyLight.withValues(alpha: 0.80),
              const Color(0xFFCFE0FB).withValues(alpha: 0.60),
            ],
          ).createShader(full),
      );
    }

    // Bottom swoosh.
    final swoosh = Path()
      ..moveTo(0, h * 0.95)
      ..quadraticBezierTo(w * 0.45, h * 0.84, w, h * 0.76)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      swoosh,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.blue.withValues(alpha: 0.75),
          ],
        ).createShader(full),
    );
    final highlight = Path()
      ..moveTo(0, h * 0.975)
      ..quadraticBezierTo(w * 0.5, h * 0.89, w, h * 0.83)
      ..lineTo(w, h * 0.86)
      ..quadraticBezierTo(w * 0.5, h * 0.92, 0, h * 0.99)
      ..close();
    canvas.drawPath(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(LoginBackgroundPainter old) => old.split != split;
}
