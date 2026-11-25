import 'dart:typed_data';

// โมเดลโครงการ: ใช้ชื่อฟิลด์ JSON ชุดเดียวกับแอป HomeConnect (homeconnect/lib/pages/add_project_page.dart)
// เพื่อให้ต่อกับ backend เดียวกันได้ในอนาคต

const kProjectTypes = [
  'คอนโด',
  'บ้านเดี่ยว',
  'ทาวน์โฮม',
  'ทาวน์เฮาส์',
  'โฮมออฟฟิศ',
  'พูลวิลล่า',
];

const kProjectStatuses = [
  'เตรียมเปิดตัว',
  'เปิดขาย',
  'กำลังก่อสร้าง',
  'สร้างเสร็จพร้อมอยู่',
  'ปิดการขาย',
];

/// ยูนิต/ห้องในโครงการ (ทุกช่องไม่บังคับ)
class ProjectUnit {
  const ProjectUnit({
    this.unitNo = '',
    this.roomType = '',
    this.bedrooms,
    this.bathrooms,
    this.area,
    this.floor = '',
    this.size = '',
    this.direction = '',
  });

  final String unitNo;
  final String roomType;
  final int? bedrooms;
  final int? bathrooms;
  final double? area; // ตร.ม.
  final String floor;
  final String size;
  final String direction;

  bool get isEmpty =>
      unitNo.isEmpty &&
      roomType.isEmpty &&
      bedrooms == null &&
      bathrooms == null &&
      area == null &&
      floor.isEmpty &&
      size.isEmpty &&
      direction.isEmpty;

  Map<String, dynamic> toJson() => {
    'unit_no': unitNo,
    'room_type': roomType,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'area': area,
    'floor': floor,
    'size': size,
    'direction': direction,
  };

  factory ProjectUnit.fromJson(Map<String, dynamic> j) => ProjectUnit(
    unitNo: (j['unit_no'] as String?) ?? '',
    roomType: (j['room_type'] as String?) ?? '',
    bedrooms: (j['bedrooms'] as num?)?.toInt(),
    bathrooms: (j['bathrooms'] as num?)?.toInt(),
    area: (j['area'] as num?)?.toDouble(),
    floor: (j['floor'] as String?) ?? '',
    size: (j['size'] as String?) ?? '',
    direction: (j['direction'] as String?) ?? '',
  );
}

class NewProject {
  NewProject({
    required this.name,
    required this.type,
    required this.developer,
    required this.province,
    required this.district,
    this.subDistrict = '',
    required this.address,
    required this.imageBytes,
    this.facilities = const [],
    this.units = const [],
    this.latitude,
    this.longitude,
    required this.startPrice,
    this.maxPrice,
    this.contractPrice,
    this.reservationFee,
    this.contractFee,
    required this.downPaymentPercent,
    this.commonFee,
    this.commonFeeUnit,
    this.serviceFee,
    this.otherCostNote,
    this.priceNote = '',
    this.discountType = '',
    this.discountValue,
    this.discountUntil = '',
    required this.commissionPercent,
    this.commissionAmount,
    required this.commissionBase,
    this.commissionTerms = '',
    this.saleStart,
    this.promoEnd,
    required this.status,
    required this.contactName,
    required this.contactPhone,
    this.contactEmail = '',
  });

  /// id แถวในตาราง projects ของ Supabase (null = ยังไม่ได้บันทึกขึ้นเซิร์ฟเวอร์)
  /// ที่เก็บข้อมูลเป็นคนตั้งค่าให้หลังบันทึก
  String? id;

  final String name;
  final String type;
  final String developer;
  final String province;
  final String district;
  final String subDistrict; // แขวง/ตำบล (เว็บแอดมินเพิ่มเอง แอปยังไม่มีช่องนี้)
  final String address;

  /// รูปเก็บเป็น bytes (เว็บไม่มีไฟล์ในเครื่องให้อ้างอิง)
  final List<Uint8List> imageBytes;
  final List<String> facilities;
  final List<ProjectUnit> units;
  final double? latitude;
  final double? longitude;

  final double startPrice;
  final double? maxPrice;
  final double? contractPrice;
  final double? reservationFee;
  final double? contractFee;
  final int downPaymentPercent;
  final double? commonFee;
  final String? commonFeeUnit;
  final double? serviceFee;
  final String? otherCostNote;
  final String priceNote;
  final String discountType; // '' = ไม่มีส่วนลด, 'amount' = บาท, 'percent' = %
  final double? discountValue;
  final String discountUntil;

  final double commissionPercent;
  final double? commissionAmount;
  final String commissionBase;
  final String commissionTerms;
  final DateTime? saleStart;
  final DateTime? promoEnd;
  final String status;

  final String contactName;
  final String contactPhone;
  final String contactEmail;

  /// JSON แบบเดียวกับแอป (รูปไม่ได้อยู่ในนี้ ที่เก็บข้อมูลจะใส่เพิ่มเอง)
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'developer': developer,
    'province': province,
    'district': district,
    'sub_district': subDistrict,
    'address': address,
    'image_paths': <String>[],
    'facilities': facilities,
    'units': units.map((u) => u.toJson()).toList(),
    'latitude': latitude,
    'longitude': longitude,
    'start_price': startPrice,
    'max_price': maxPrice,
    'discount_type': discountType,
    'discount_value': discountValue,
    'discount_until': discountUntil,
    'contract_price': contractPrice,
    'reservation_fee': reservationFee,
    'contract_fee': contractFee,
    'down_payment_percent': downPaymentPercent,
    'common_fee': commonFee,
    'common_fee_unit': commonFeeUnit,
    'service_fee': serviceFee,
    'other_cost_note': otherCostNote,
    'price_note': priceNote,
    'commission_percent': commissionPercent,
    'commission_amount': commissionAmount,
    'commission_base': commissionBase,
    'commission_terms': commissionTerms,
    'sale_start': saleStart?.toIso8601String(),
    'promo_end': promoEnd?.toIso8601String(),
    'status': status,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'contact_email': contactEmail,
  };

  factory NewProject.fromJson(Map<String, dynamic> j, List<Uint8List> images) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    DateTime? t(String k) =>
        j[k] == null ? null : DateTime.tryParse(j[k] as String);
    return NewProject(
      name: (j['name'] as String?) ?? '',
      type: (j['type'] as String?) ?? '',
      developer: (j['developer'] as String?) ?? '',
      province: (j['province'] as String?) ?? '',
      district: (j['district'] as String?) ?? '',
      subDistrict: (j['sub_district'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      imageBytes: images,
      facilities: List<String>.from(j['facilities'] ?? const []),
      units: [
        for (final u in (j['units'] as List?) ?? const [])
          ProjectUnit.fromJson(Map<String, dynamic>.from(u as Map)),
      ],
      latitude: d('latitude'),
      longitude: d('longitude'),
      startPrice: d('start_price') ?? 0,
      maxPrice: d('max_price'),
      contractPrice: d('contract_price'),
      reservationFee: d('reservation_fee'),
      contractFee: d('contract_fee'),
      downPaymentPercent: (j['down_payment_percent'] as num?)?.toInt() ?? 10,
      commonFee: d('common_fee'),
      commonFeeUnit: j['common_fee_unit'] as String?,
      serviceFee: d('service_fee'),
      otherCostNote: j['other_cost_note'] as String?,
      priceNote: (j['price_note'] as String?) ?? '',
      discountType: (j['discount_type'] as String?) ?? '',
      discountValue: d('discount_value'),
      discountUntil: (j['discount_until'] as String?) ?? '',
      commissionPercent: d('commission_percent') ?? 0,
      commissionAmount: d('commission_amount'),
      commissionBase: (j['commission_base'] as String?) ?? '',
      commissionTerms: (j['commission_terms'] as String?) ?? '',
      saleStart: t('sale_start'),
      promoEnd: t('promo_end'),
      status: (j['status'] as String?) ?? 'เปิดขาย',
      contactName: (j['contact_name'] as String?) ?? '',
      contactPhone: (j['contact_phone'] as String?) ?? '',
      contactEmail: (j['contact_email'] as String?) ?? '',
    );
  }
}
