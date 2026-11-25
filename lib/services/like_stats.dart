import 'package:flutter/foundation.dart';

import '../models/project.dart';

/// ยอด "กดใจ" (❤) ของแต่ละโครงการจากแอป HomeConnect
///
/// ในแอป เมื่อผู้ใช้กดหัวใจ โครงการจะเข้า "รายการโปรด" (FavoriteStore)
/// แต่ตอนนี้แอปเก็บไว้ในเครื่องผู้ใช้เท่านั้น ยังไม่มี backend กลาง
/// หน้าแอดมินจึงยังอ่านยอดจริงไม่ได้ — ค่าเริ่มต้นเป็น 0 ทุกโครงการ
///
/// TODO: เมื่อมี backend ให้ดึงยอดกดใจ (เช่น นับจากตาราง favorites
/// group by project) แล้วเรียก [setAll] — หน้ารายงานจะอัปเดตเอง
class LikeStats extends ChangeNotifier {
  LikeStats._();
  static final LikeStats instance = LikeStats._();

  /// key = ชื่อโครงการ (ยังไม่มี id กลางระหว่างแอปกับแอดมิน)
  final Map<String, int> _likes = {};

  int likesOf(NewProject p) => _likes[p.name] ?? 0;

  bool get hasData => _likes.values.any((v) => v > 0);

  void setAll(Map<String, int> likesByProjectName) {
    _likes
      ..clear()
      ..addAll(likesByProjectName);
    notifyListeners();
  }
}
