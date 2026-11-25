import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'panel.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.trend,
    this.trendNote,
  });

  final IconData icon;
  final String value;
  final String label;

  /// แนวโน้ม เช่น "+2" (null = ไม่แสดงแถวแนวโน้ม)
  final String? trend;
  final String? trendNote;

  static const _up = Color(0xFF1FA463);

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE3EDFD), Color(0xFFCADDFB)],
                  ),
                ),
                child: Icon(icon, color: AppColors.blue, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _up.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: _up,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  trend!,
                  style: const TextStyle(
                    color: _up,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trendNote ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.hint, fontSize: 12),
                  ),
                ),
                const _MiniBars(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars();

  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 12.0, 15.0, 19.0, 24.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < heights.length; i++)
          Container(
            width: 4,
            height: heights[i],
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.2 + i * 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
