import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const navy = Color(0xFF0B2563);
  static const primary = Color(0xFF123C8C);
  static const blue = Color(0xFF1E5BD8);
  static const skyLight = Color(0xFFEAF2FF);
  static const border = Color(0xFFC9D6EE);
  static const hint = Color(0xFF6B7A99);

  /// พื้นหลังหน้าเนื้อหา (ทุกหน้าในแดชบอร์ด)
  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3F7FE), Color(0xFFE6EFFC)],
  );
}
