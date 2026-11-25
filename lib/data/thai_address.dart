import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ข้อมูลที่อยู่ไทย: จังหวัด → เขต/อำเภอ → แขวง/ตำบล
///
/// ไฟล์ assets/data/thai_address.json สร้างจากชุดข้อมูล kongvut/thai-province-data
/// (77 จังหวัด, 930 อำเภอ, 7,436 ตำบล) รูปแบบ:
/// `{ "จังหวัด": { "อำเภอ": ["ตำบล", ...] } }`
class ThaiAddress {
  ThaiAddress._(this._tree);

  final Map<String, Map<String, List<String>>> _tree;

  static Future<ThaiAddress>? _loading;

  /// โหลดครั้งเดียว ใช้ซ้ำได้ทั้งแอป
  static Future<ThaiAddress> load() => _loading ??= _load();

  /// ล้างตัวที่จำไว้ (ใช้ในเทสต์: งานโหลดที่เริ่มในนาฬิกาจำลองของเทสต์ก่อนหน้า
  /// จะไม่มีวันเสร็จ)
  @visibleForTesting
  static void debugReset() => _loading = null;

  static Future<ThaiAddress> _load() async {
    // อ่านเป็น bytes แล้วถอดรหัสเอง: loadString จะส่งไปถอดใน isolate อื่น
    // เมื่อไฟล์ใหญ่ ซึ่งบนเว็บไม่ได้ช่วยอะไรและทำให้เทสต์ค้าง
    final bytes = await rootBundle.load('assets/data/thai_address.json');
    final json = jsonDecode(
      utf8.decode(bytes.buffer.asUint8List()),
    ) as Map<String, dynamic>;
    return ThaiAddress._({
      for (final p in json.entries)
        p.key: {
          for (final d in (p.value as Map<String, dynamic>).entries)
            d.key: List<String>.from(d.value as List),
        },
    });
  }

  List<String> districts(String? province) =>
      _tree[province]?.keys.toList() ?? const [];

  List<String> subdistricts(String? province, String? district) =>
      _tree[province]?[district] ?? const [];
}
