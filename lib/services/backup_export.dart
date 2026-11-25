import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/admin_user.dart';
import '../models/project.dart';
import 'xlsx_writer.dart';

/// ขนาดรูปย่อในชีต (พิกเซล)
const _thumbW = 150;
const _thumbH = 96;
const _maxImageColumns = 10;

String _two(int n) => n.toString().padLeft(2, '0');

/// วันที่แบบไทย พ.ศ. เช่น 25/11/2569
String _date(DateTime? d) =>
    d == null ? '' : '${_two(d.day)}/${_two(d.month)}/${d.year + 543}';

String _dateTime(DateTime d) =>
    '${_date(d)} ${_two(d.hour)}:${_two(d.minute)} น.';

/// ย่อรูปให้พอดีกรอบ (เก็บเป็น PNG ความละเอียด 2 เท่าเพื่อให้คมตอนซูม)
Future<XlsxImage?> makeThumbnail(Uint8List bytes) async {
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final desc = await ui.ImageDescriptor.encoded(buffer);
    final scale = math.min(
      1.0,
      math.min(_thumbW / desc.width, _thumbH / desc.height),
    );
    final w = math.max(1, (desc.width * scale).round());
    final h = math.max(1, (desc.height * scale).round());
    final codec = await desc.instantiateCodec(
      targetWidth: math.min(desc.width, w * 2),
      targetHeight: math.min(desc.height, h * 2),
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    desc.dispose();
    buffer.dispose();
    if (data == null) return null;
    return XlsxImage(data.buffer.asUint8List(), w, h);
  } catch (_) {
    return null; // ไฟล์รูปเสีย — ข้ามไป
  }
}

/// สร้างไฟล์ Excel สำรองข้อมูล: ชีตโครงการ (มีรูป) / ยูนิต / ผู้ใช้งาน
///
/// [thumbnail] เปลี่ยนได้ตอนเทสต์ (ในเทสต์ถอดรหัสรูปจริงไม่ได้)
Future<Uint8List> buildBackupXlsx({
  required List<NewProject> projects,
  required List<AdminUser> users,
  Future<XlsxImage?> Function(Uint8List) thumbnail = makeThumbnail,
}) async {
  // เรียงเก่า → ใหม่ แบบคำตอบใน Google Forms
  final ordered = projects.reversed.toList();
  final imageCols = math.min(
    _maxImageColumns,
    ordered.fold<int>(0, (m, p) => math.max(m, p.imageBytes.length)),
  );

  String money(double? v) => v == null ? '' : v.toString();
  Object? num(double? v) => v;

  final projectRows = <List<Object?>>[];
  for (var i = 0; i < ordered.length; i++) {
    final p = ordered[i];
    final thumbs = <Object?>[];
    for (var k = 0; k < imageCols; k++) {
      thumbs.add(
        k < p.imageBytes.length ? await thumbnail(p.imageBytes[k]) : null,
      );
    }
    projectRows.add([
      i + 1,
      p.name,
      ...thumbs,
      p.type,
      p.developer,
      p.status,
      p.province,
      p.district,
      p.subDistrict,
      p.address,
      num(p.latitude),
      num(p.longitude),
      num(p.startPrice),
      num(p.maxPrice),
      p.downPaymentPercent,
      num(p.reservationFee),
      num(p.contractPrice),
      num(p.contractFee),
      num(p.commonFee),
      p.commonFeeUnit ?? '',
      num(p.serviceFee),
      p.otherCostNote ?? '',
      switch (p.discountType) {
        'amount' => '${money(p.discountValue)} บาท',
        'percent' => '${money(p.discountValue)}%',
        _ => '',
      },
      p.discountUntil,
      p.priceNote,
      p.commissionPercent,
      num(p.commissionAmount),
      p.commissionBase,
      p.commissionTerms,
      _date(p.saleStart),
      _date(p.promoEnd),
      p.facilities.join(', '),
      p.units.length,
      p.contactName,
      p.contactPhone,
      p.contactEmail,
      p.imageBytes.length,
    ]);
  }

  final projectHeaders = [
    'ลำดับ',
    'ชื่อโครงการ',
    for (var k = 0; k < imageCols; k++) 'รูปที่ ${k + 1}',
    'ประเภท',
    'บริษัทผู้พัฒนา',
    'สถานะ',
    'จังหวัด',
    'เขต/อำเภอ',
    'แขวง/ตำบล',
    'ที่อยู่',
    'ละติจูด',
    'ลองจิจูด',
    'ราคาเริ่มต้น (บาท)',
    'ราคาสูงสุด (บาท)',
    'เงินดาวน์ (%)',
    'เงินจอง (บาท)',
    'ราคาหน้าสัญญา (บาท)',
    'เงินทำสัญญา (บาท)',
    'ค่าส่วนกลาง',
    'หน่วยค่าส่วนกลาง',
    'ค่าบริการ',
    'ค่าใช้จ่ายอื่น',
    'ส่วนลด',
    'ส่วนลดถึง',
    'โปรโมชั่น/หมายเหตุ',
    'ค่าคอมมิชชั่น (%)',
    'ค่าคอมมิชชั่น (บาท)',
    'คิดค่าคอมจาก',
    'เงื่อนไขค่าคอม',
    'วันที่เริ่มขาย',
    'วันสิ้นสุดโปรโมชั่น',
    'สิ่งอำนวยความสะดวก',
    'จำนวนยูนิต',
    'ผู้ติดต่อ',
    'เบอร์ติดต่อ',
    'อีเมลติดต่อ',
    'จำนวนรูปทั้งหมด',
  ];

  final unitRows = <List<Object?>>[
    for (final p in ordered)
      for (final u in p.units)
        [
          p.name,
          u.unitNo,
          u.roomType,
          u.bedrooms,
          u.bathrooms,
          u.area,
          u.floor,
          u.size,
          u.direction,
        ],
  ];

  final orderedUsers = users.reversed.toList();
  final userRows = <List<Object?>>[
    for (var i = 0; i < orderedUsers.length; i++)
      [
        i + 1,
        _dateTime(orderedUsers[i].createdAt),
        orderedUsers[i].name,
        orderedUsers[i].email,
        orderedUsers[i].phone,
        orderedUsers[i].role,
        orderedUsers[i].status,
      ],
  ];

  return buildXlsx([
    XlsxSheet(
      name: 'โครงการ',
      headers: projectHeaders,
      rows: projectRows,
      // กว้างพอสำหรับรูปย่อ 150px
      columnWidths: {
        0: 7,
        1: 28,
        for (var k = 0; k < imageCols; k++) 2 + k: 22,
        2 + imageCols + 8: 36, // ที่อยู่
      },
      rowHeight: imageCols > 0 ? (_thumbH + 8) * 0.75 : null,
    ),
    XlsxSheet(
      name: 'ยูนิต',
      headers: const [
        'โครงการ',
        'เลขที่ยูนิต',
        'ประเภทห้อง',
        'ห้องนอน',
        'ห้องน้ำ',
        'พื้นที่ (ตร.ม.)',
        'ชั้น',
        'ขนาด',
        'ทิศ',
      ],
      rows: unitRows,
      columnWidths: const {0: 28},
    ),
    XlsxSheet(
      name: 'ผู้ใช้งาน',
      headers: const [
        'ลำดับ',
        'สมัครเมื่อ',
        'ชื่อ-สกุล',
        'อีเมล',
        'เบอร์โทรศัพท์',
        'ประเภทผู้ใช้',
        'สถานะ',
      ],
      rows: userRows,
      columnWidths: const {0: 7, 1: 20, 2: 28, 3: 28},
    ),
  ]);
}

/// ชื่อไฟล์ เช่น A2_สำรองข้อมูล_2026-11-25.xlsx
String backupFileName([DateTime? now]) {
  final d = now ?? DateTime.now();
  return 'A2_สำรองข้อมูล_${d.year}-${_two(d.month)}-${_two(d.day)}.xlsx';
}
