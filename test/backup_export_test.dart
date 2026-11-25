import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:admin_a2h/models/admin_user.dart';
import 'package:admin_a2h/models/project.dart';
import 'package:admin_a2h/services/backup_export.dart';
import 'package:admin_a2h/services/xlsx_writer.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG 1x1 จริง
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

NewProject _p(String name, int images) => NewProject(
  name: name,
  type: 'คอนโด',
  developer: 'A2 & Co <test>',
  province: 'กรุงเทพมหานคร',
  district: 'บางนา',
  address: 'ถนนบางนา-ตราด',
  imageBytes: [for (var i = 0; i < images; i++) Uint8List.fromList(_png)],
  facilities: const ['สระว่ายน้ำ', 'ฟิตเนส'],
  units: const [ProjectUnit(unitNo: 'A-101', roomType: '1 ห้องนอน')],
  startPrice: 2500000,
  downPaymentPercent: 10,
  commissionPercent: 3,
  commissionBase: 'ราคาขาย (สุทธิ)',
  status: 'เปิดขาย',
  contactName: 'คุณเอ',
  contactPhone: '0812345678',
);

void main() {
  test('backup xlsx has 3 sheets, header row and embedded images', () async {
    final bytes = await buildBackupXlsx(
      projects: [_p('Life Bangna', 2), _p('Plum Condo', 3)],
      users: [
        AdminUser(
          id: 'u1',
          name: 'Natcha Srisuk',
          email: 'natcha@hotmail.com',
          phone: '080-555-1212',
          createdAt: DateTime(2025, 10, 5, 16, 45),
        ),
      ],
      thumbnail: (b) async => XlsxImage(b, 120, 80),
    );

    // เก็บไว้ตรวจด้วยเครื่องมืออื่น
    Directory('build').createSync(recursive: true);
    File('build/test_backup.xlsx').writeAsBytesSync(bytes);

    final zip = ZipDecoder().decodeBytes(bytes);
    String text(String path) =>
        utf8.decode(zip.findFile(path)!.content as List<int>);

    expect(zip.files.first.name, '[Content_Types].xml');
    final wb = text('xl/workbook.xml');
    expect(wb, contains('name="โครงการ"'));
    expect(wb, contains('name="ยูนิต"'));
    expect(wb, contains('name="ผู้ใช้งาน"'));

    final sheet1 = text('xl/worksheets/sheet1.xml');
    expect(sheet1, contains('รูปที่ 3')); // คอลัมน์รูปตามจำนวนมากสุด
    expect(sheet1, contains('A2 &amp; Co &lt;test&gt;')); // escape แล้ว
    expect(sheet1, contains('<drawing r:id="rId1"/>'));
    // 2 + 3 = 5 รูป
    expect(zip.files.where((f) => f.name.startsWith('xl/media/')).length, 5);
    expect(text('xl/worksheets/sheet3.xml'), contains('05/10/2568 16:45 น.'));
    expect(text('xl/worksheets/sheet2.xml'), contains('A-101'));
  });
}
