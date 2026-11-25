import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// ที่เก็บโครงการของระบบแอดมิน
///
/// ตอนนี้ยังไม่มี backend จึงเก็บใน localStorage ของเบราว์เซอร์
/// (รูปเก็บเป็น base64, พื้นที่ประมาณ 5MB) — ข้อมูลนี้ยังไม่เชื่อมกับแอป HomeConnect
/// TODO: เปลี่ยนเป็นการเรียก API เมื่อมี backend
class ProjectStore extends ChangeNotifier {
  ProjectStore._();
  static final ProjectStore instance = ProjectStore._();

  static const _prefsKey = 'admin_a2h_projects_v1';

  final List<NewProject> _items = [];

  /// โครงการที่เก็บรูปลงเบราว์เซอร์ไม่ได้ (พื้นที่เต็ม) — รูปจะหายเมื่อรีเฟรช
  final Set<NewProject> _imagesNotStored = {};
  Future<void>? _loading;

  /// เรียงจากใหม่ไปเก่า
  List<NewProject> get projects => List.unmodifiable(_items);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      for (final e in jsonDecode(raw) as List) {
        final rec = Map<String, dynamic>.from(e as Map);
        final images = <Uint8List>[
          for (final b in List<String>.from(rec['images_b64'] ?? const []))
            base64Decode(b),
        ];
        _items.add(NewProject.fromJson(rec, images));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('โหลดโครงการไม่สำเร็จ: $e');
    }
  }

  /// เพิ่มโครงการ คืนข้อความเตือนถ้าบันทึกไม่สมบูรณ์ หรือ null ถ้าปกติ
  Future<String?> add(NewProject p) async {
    await load();
    _items.insert(0, p);
    notifyListeners();
    return _persist(changed: p);
  }

  /// แก้ไขโครงการเดิม (แทนที่ตำแหน่งเดิมในรายการ)
  Future<String?> update(NewProject old, NewProject updated) async {
    await load();
    final i = _items.indexOf(old);
    if (i < 0) return add(updated);
    _items[i] = updated;
    _imagesNotStored.remove(old);
    notifyListeners();
    return _persist(changed: updated);
  }

  Future<String?> remove(NewProject p) async {
    await load();
    _items.remove(p);
    _imagesNotStored.remove(p);
    notifyListeners();
    return _persist();
  }

  /// เขียนรายการทั้งหมดลงเบราว์เซอร์ ถ้าพื้นที่ไม่พอ จะลองเก็บโครงการที่เพิ่ง
  /// เปลี่ยนแบบไม่มีรูป
  Future<String?> _persist({NewProject? changed}) async {
    String encode() => jsonEncode([
      for (final p in _items)
        p.toJson()
          ..['images_b64'] = _imagesNotStored.contains(p)
              ? <String>[]
              : p.imageBytes.map(base64Encode).toList(),
    ]);

    final prefs = await SharedPreferences.getInstance();
    Future<bool> write() async {
      try {
        return await prefs.setString(_prefsKey, encode());
      } catch (_) {
        return false;
      }
    }

    if (await write()) return null;
    if (changed != null) {
      _imagesNotStored.add(changed);
      if (await write()) {
        return 'บันทึกแล้ว แต่รูปใหญ่เกินที่เบราว์เซอร์เก็บได้ รูปจะหายเมื่อรีเฟรช';
      }
    }
    return 'พื้นที่เก็บข้อมูลของเบราว์เซอร์เต็ม การเปลี่ยนแปลงจะอยู่จนกว่าจะรีเฟรช';
  }
}
