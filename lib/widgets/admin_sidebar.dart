import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'a2_logo.dart';

class AdminNavItem {
  const AdminNavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Sidebar menu entries. The index is used as the page id.
const adminNavItems = [
  AdminNavItem('หน้าหลัก', Icons.home_rounded),
  AdminNavItem('เพิ่มโครงการ', Icons.add_home_work_rounded),
  AdminNavItem('จัดการโครงการ', Icons.business_rounded),
  AdminNavItem('จัดการผู้ใช้งาน', Icons.person_rounded),
  AdminNavItem('รายงานและสถิติ', Icons.bar_chart_rounded),
  AdminNavItem('ตั้งค่าระบบ', Icons.settings_rounded),
];

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2563), Color(0xFF0E3A8F), Color(0xFF1349B0)],
        ),
      ),
      child: CustomPaint(
        painter: _SidebarWavesPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    const A2Logo(color: Colors.white, width: 120),
                    const SizedBox(height: 32),
                    for (var i = 0; i < adminNavItems.length; i++)
                      _NavTile(
                        item: adminNavItems[i],
                        selected: i == selected,
                        onTap: () => onSelect(i),
                      ),
                    const Spacer(),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.15),
                      indent: 20,
                      endIndent: 20,
                    ),
                    _NavTile(
                      item: const AdminNavItem(
                        'ออกจากระบบ',
                        Icons.logout_rounded,
                      ),
                      selected: false,
                      onTap: onLogout,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flowing light lines in the lower part of the sidebar (like the mockup).
class _SidebarWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft glow behind the waves.
    final glowRect = Rect.fromCircle(
      center: Offset(w * 0.9, h * 0.82),
      radius: w * 1.1,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4A8BFF).withValues(alpha: 0.35),
            const Color(0xFF4A8BFF).withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    void waveBand({
      required double baseY,
      required double amplitude,
      required double phase,
      required int lines,
      required double maxAlpha,
    }) {
      for (var k = 0; k < lines; k++) {
        final t = k / (lines - 1);
        final path = Path();
        for (var x = -10.0; x <= w + 10; x += 4) {
          final y =
              baseY +
              k * 5 +
              math.sin(x / w * math.pi * 1.6 + phase + t * 1.4) *
                  amplitude *
                  (0.6 + t * 0.6);
          if (x == -10.0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        // Brighter in the middle of the band, fading at both edges.
        final alpha = maxAlpha * (1 - (t - 0.5).abs() * 1.6).clamp(0.15, 1.0);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: alpha),
        );
      }
    }

    waveBand(
      baseY: h * 0.70,
      amplitude: h * 0.035,
      phase: 0.3,
      lines: 18,
      maxAlpha: 0.38,
    );
    waveBand(
      baseY: h * 0.80,
      amplitude: h * 0.025,
      phase: 2.2,
      lines: 12,
      maxAlpha: 0.24,
    );
  }

  @override
  bool shouldRepaint(_SidebarWavesPainter oldDelegate) => false;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF3A78EC), Color(0xFF1E5BD8)],
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(item.icon, color: Colors.white, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
