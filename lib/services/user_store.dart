import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_user.dart';

/// ที่เก็บผู้ใช้งานของระบบแอดมิน
///
/// ยังไม่มี backend จึงเก็บใน localStorage ของเบราว์เซอร์ และใส่ผู้ใช้ตัวอย่าง
/// 5 คน (ตามภาพตัวอย่าง) ตอนเปิดครั้งแรก
/// TODO: ดึงรายชื่อผู้ใช้จริงจาก API ของแอป HomeConnect เมื่อมี backend
class UserStore extends ChangeNotifier {
  UserStore._();
  static final UserStore instance = UserStore._();

  static const _prefsKey = 'admin_a2h_users_v1';

  final List<AdminUser> _items = [];
  Future<void>? _loading;

  /// เรียงจากสมัครล่าสุดไปเก่าสุด
  List<AdminUser> get users => List.unmodifiable(_items);

  Future<void> load() => _loading ??= _load();

  @visibleForTesting
  void debugReset() {
    _items.clear();
    _loading = null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        _items.addAll(_sampleUsers());
        await _persist();
      } else {
        for (final e in jsonDecode(raw) as List) {
          _items.add(AdminUser.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
      _sort();
      notifyListeners();
    } catch (e) {
      debugPrint('โหลดผู้ใช้ไม่สำเร็จ: $e');
    }
  }

  void _sort() => _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool emailTaken(String email, {AdminUser? except}) {
    final e = email.trim().toLowerCase();
    return _items.any((u) => u != except && u.email.toLowerCase() == e);
  }

  Future<void> add(AdminUser u) async {
    await load();
    _items.add(u);
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> update(AdminUser old, AdminUser updated) async {
    await load();
    final i = _items.indexOf(old);
    if (i < 0) return add(updated);
    _items[i] = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(AdminUser u) async {
    await load();
    _items.remove(u);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode([for (final u in _items) u.toJson()]),
      );
    } catch (e) {
      debugPrint('บันทึกผู้ใช้ไม่สำเร็จ: $e');
    }
  }

  static List<AdminUser> _sampleUsers() => [
    AdminUser(
      id: 'u1',
      name: 'ศิริพรรณ รัตนชัยวณิชกุล',
      email: 'siriphan@example.com',
      phone: '082-123-4567',
      createdAt: DateTime(2025, 10, 12, 14, 32),
    ),
    AdminUser(
      id: 'u2',
      name: 'Thanakrit Wongsa',
      email: 'thanakrit@gmail.com',
      phone: '091-987-6543',
      createdAt: DateTime(2025, 10, 10, 9, 20),
    ),
    AdminUser(
      id: 'u3',
      name: 'Natcha Srisuk',
      email: 'natcha@hotmail.com',
      phone: '080-555-1212',
      role: 'ผู้ดูแลระบบ',
      createdAt: DateTime(2025, 10, 5, 16, 45),
    ),
    AdminUser(
      id: 'u4',
      name: 'Pongsakorn J.',
      email: 'pongsakorn@gmail.com',
      phone: '063-777-8888',
      status: 'ระงับใช้งาน',
      createdAt: DateTime(2025, 10, 1, 11, 12),
    ),
    AdminUser(
      id: 'u5',
      name: 'Kanyanat Boonma',
      email: 'kanyanat@gmail.com',
      phone: '089-222-3333',
      createdAt: DateTime(2025, 9, 28, 13, 27),
    ),
  ];
}
