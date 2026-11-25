import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// การตั้งค่าระบบแอดมิน (เก็บใน localStorage ของเบราว์เซอร์)
/// TODO: ย้ายไปเก็บที่ backend เมื่อมี
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _prefsKey = 'admin_a2h_settings_v1';

  /// ค่าเริ่มต้นของทุกการตั้งค่า
  static const defaults = <String, Object>{
    // ข้อมูลบริษัท
    'company_name': 'A2 Property',
    'company_address': '',
    'company_phone': '',
    'company_email': '',
    'company_line': '',
    'company_facebook': '',
    'company_website': '',
    // การแจ้งเตือน
    'notify_new_user': true,
    'notify_like': true,
    'notify_promo_end': true,
    'notify_weekly_email': false,
    // ความปลอดภัย
    'auto_logout_minutes': 30, // 0 = ไม่ออกอัตโนมัติ
    'max_login_attempts': 5,
    'two_factor': false,
  };

  final Map<String, Object> _values = Map.of(defaults);
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  @visibleForTesting
  void debugReset() {
    _values
      ..clear()
      ..addAll(defaults);
    _loading = null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in saved.entries) {
          final def = defaults[e.key];
          // ข้ามค่าที่ชนิดไม่ตรง (กันข้อมูลเสีย)
          if (def != null && e.value.runtimeType == def.runtimeType) {
            _values[e.key] = e.value as Object;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('โหลดการตั้งค่าไม่สำเร็จ: $e');
    }
  }

  String text(String key) => _values[key] as String;
  bool flag(String key) => _values[key] as bool;
  int number(String key) => _values[key] as int;

  Future<void> setAll(Map<String, Object> changes) async {
    await load();
    _values.addAll(changes);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_values));
    } catch (e) {
      debugPrint('บันทึกการตั้งค่าไม่สำเร็จ: $e');
    }
  }
}
