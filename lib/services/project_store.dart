import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// ที่เก็บโครงการของระบบแอดมิน
///
/// ใช้งานจริง: เก็บใน Supabase (ตาราง projects / project_units / project_images)
/// ตอนเทสต์: เก็บใน localStorage ของเบราว์เซอร์ (รูปเก็บเป็น base64)
/// ที่เก็บโครงการบนเซิร์ฟเวอร์ (ของจริง = Supabase)
abstract class ProjectBackend {
  Future<List<NewProject>> loadAll();

  /// บันทึกโครงการใหม่ แล้วตั้งค่า [NewProject.id]
  Future<void> insert(NewProject p);
  Future<void> update(NewProject old, NewProject p);
  Future<void> delete(NewProject p);
}

/// บันทึกขึ้นเซิร์ฟเวอร์ไม่สำเร็จ — [message] เป็นภาษาไทยสำหรับแสดงผู้ใช้
class ProjectSaveException implements Exception {
  const ProjectSaveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProjectStore extends ChangeNotifier {
  ProjectStore._();
  static final ProjectStore instance = ProjectStore._();

  /// ถ้าตั้งไว้ (main.dart) ข้อมูลจะอยู่บนเซิร์ฟเวอร์และขึ้นในแอป HomeConnect
  /// ถ้าไม่ตั้ง (ตอนเทสต์) เก็บใน localStorage ของเบราว์เซอร์แบบเดิม
  ProjectBackend? _remote;

  void useBackend(ProjectBackend backend) {
    _remote = backend;
    _items.clear();
    _loading = null;
  }

  /// ข้อความเมื่อโหลดจากเซิร์ฟเวอร์ไม่สำเร็จ (null = ปกติ)
  String? loadError;

  /// โหลดใหม่จากเซิร์ฟเวอร์ (เช่น หลังเข้าสู่ระบบ)
  Future<void> reload() {
    _items.clear();
    _loading = null;
    return load();
  }

  static String _err(Object e) => 'บันทึกขึ้นเซิร์ฟเวอร์ไม่สำเร็จ: $e';

  static const _prefsKey = 'admin_a2h_projects_v1';

  final List<NewProject> _items = [];

  /// โครงการที่เก็บรูปลงเบราว์เซอร์ไม่ได้ (พื้นที่เต็ม) — รูปจะหายเมื่อรีเฟรช
  final Set<NewProject> _imagesNotStored = {};
  Future<void>? _loading;

  /// เรียงจากใหม่ไปเก่า
  List<NewProject> get projects => List.unmodifiable(_items);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final list = await remote.loadAll();
        _items
          ..clear()
          ..addAll(list);
        loadError = null;
      } catch (e) {
        loadError = 'โหลดโครงการจากเซิร์ฟเวอร์ไม่สำเร็จ: $e';
        debugPrint(loadError);
      }
      notifyListeners();
      return;
    }
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
    final remote = _remote;
    if (remote != null) {
      try {
        await remote.insert(p);
      } catch (e) {
        throw ProjectSaveException(_err(e));
      }
      _items.insert(0, p);
      notifyListeners();
      return null;
    }
    _items.insert(0, p);
    notifyListeners();
    return _persist(changed: p);
  }

  /// แก้ไขโครงการเดิม (แทนที่ตำแหน่งเดิมในรายการ)
  Future<String?> update(NewProject old, NewProject updated) async {
    await load();
    final remote = _remote;
    if (remote != null) {
      try {
        await remote.update(old, updated);
      } catch (e) {
        throw ProjectSaveException(_err(e));
      }
      final i = _items.indexOf(old);
      if (i < 0) {
        _items.insert(0, updated);
      } else {
        _items[i] = updated;
      }
      notifyListeners();
      return null;
    }
    final i = _items.indexOf(old);
    if (i < 0) return add(updated);
    _items[i] = updated;
    _imagesNotStored.remove(old);
    notifyListeners();
    return _persist(changed: updated);
  }

  Future<String?> remove(NewProject p) async {
    await load();
    final remote = _remote;
    if (remote != null) {
      try {
        await remote.delete(p);
      } catch (e) {
        return 'ลบไม่สำเร็จ: $e';
      }
      _items.remove(p);
      notifyListeners();
      return null;
    }
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
