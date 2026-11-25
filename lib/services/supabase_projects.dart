import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/project.dart';
import 'project_store.dart';
import 'supabase_backend.dart' show kSupabaseUrl;

/// ที่เก็บรูปโครงการใน Supabase Storage (bucket สาธารณะ แอปเปิดรูปได้โดยตรง)
const kImageBucket = 'project-images';

String publicImageUrl(String storagePath) =>
    '$kSupabaseUrl/storage/v1/object/public/$kImageBucket/$storagePath';

/// แปลงโครงการ ↔ แถวในตาราง projects (ชื่อคอลัมน์ตามฐานข้อมูลของแอป)
Map<String, dynamic> projectToRow(NewProject p) {
  String? date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
  String? text(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  return {
    'name': p.name,
    'type': p.type,
    'developer': p.developer,
    'province': p.province,
    'district': p.district,
    'sub_district': text(p.subDistrict),
    'address': text(p.address),
    'latitude': p.latitude,
    'longitude': p.longitude,
    'facilities': p.facilities,
    'start_price': p.startPrice,
    'max_price': p.maxPrice,
    'contract_price': p.contractPrice,
    'reservation_fee': p.reservationFee,
    'contract_fee': p.contractFee,
    'down_payment_percent': p.downPaymentPercent,
    'common_fee': p.commonFee,
    'common_fee_unit': text(p.commonFeeUnit),
    'service_fee': p.serviceFee,
    'other_cost_note': text(p.otherCostNote),
    'price_note': text(p.priceNote),
    'discount_type': text(p.discountType),
    'discount_value': p.discountValue,
    'discount_until': date(DateTime.tryParse(p.discountUntil)),
    'commission_percent': p.commissionPercent,
    'commission_amount': p.commissionAmount,
    'commission_base': text(p.commissionBase),
    'commission_terms': text(p.commissionTerms),
    'sale_status': p.status,
    'visibility': 'published', // โชว์ในแอปทันที
    'sale_start': date(p.saleStart),
    'promo_end': date(p.promoEnd),
    'contact_name': p.contactName,
    'contact_phone': p.contactPhone,
    'contact_email': text(p.contactEmail),
  };
}

NewProject projectFromRow(Map<String, dynamic> r, List<Uint8List> images) {
  double? d(String k) => (r[k] as num?)?.toDouble();
  DateTime? t(String k) =>
      r[k] == null ? null : DateTime.tryParse(r[k] as String);
  final units = [
    for (final u in (r['project_units'] as List?) ?? const [])
      ProjectUnit.fromJson(Map<String, dynamic>.from(u as Map)),
  ];
  return NewProject(
      name: r['name'] as String? ?? '',
      type: r['type'] as String? ?? '',
      developer: r['developer'] as String? ?? '',
      province: r['province'] as String? ?? '',
      district: r['district'] as String? ?? '',
      subDistrict: r['sub_district'] as String? ?? '',
      address: r['address'] as String? ?? '',
      imageBytes: images,
      facilities: List<String>.from(r['facilities'] ?? const []),
      units: units,
      latitude: d('latitude'),
      longitude: d('longitude'),
      startPrice: d('start_price') ?? 0,
      maxPrice: d('max_price'),
      contractPrice: d('contract_price'),
      reservationFee: d('reservation_fee'),
      contractFee: d('contract_fee'),
      downPaymentPercent: (r['down_payment_percent'] as num?)?.toInt() ?? 0,
      commonFee: d('common_fee'),
      commonFeeUnit: r['common_fee_unit'] as String?,
      serviceFee: d('service_fee'),
      otherCostNote: r['other_cost_note'] as String?,
      priceNote: r['price_note'] as String? ?? '',
      discountType: r['discount_type'] as String? ?? '',
      discountValue: d('discount_value'),
      discountUntil: r['discount_until'] as String? ?? '',
      commissionPercent: d('commission_percent') ?? 0,
      commissionAmount: d('commission_amount'),
      commissionBase: r['commission_base'] as String? ?? '',
      commissionTerms: r['commission_terms'] as String? ?? '',
      saleStart: t('sale_start'),
      promoEnd: t('promo_end'),
      status: r['sale_status'] as String? ?? 'เปิดขาย',
      contactName: r['contact_name'] as String? ?? '',
      contactPhone: r['contact_phone'] as String? ?? '',
      contactEmail: r['contact_email'] as String? ?? '',
    )
    ..id = r['id'] as String?;
}

/// เดาชนิดไฟล์รูปจาก bytes แรก ๆ
(String ext, String mime) imageType(Uint8List b) {
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return ('png', 'image/png');
  if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42) {
    return ('webp', 'image/webp');
  }
  if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49) return ('gif', 'image/gif');
  return ('jpg', 'image/jpeg');
}

class SupabaseProjectBackend implements ProjectBackend {
  sb.SupabaseClient get _c => sb.Supabase.instance.client;

  static const _select =
      '*, project_units(*), project_images(storage_path, sort_order)';

  @override
  Future<List<NewProject>> loadAll() async {
    final rows = await _c
        .from('projects')
        .select(_select)
        .order('created_at', ascending: false);
    return Future.wait([
      for (final r in rows)
        () async {
          final imgs = [...((r['project_images'] as List?) ?? const [])]
            ..sort(
              (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
                (b['sort_order'] as num?) ?? 0,
              ),
            );
          final bytes = await Future.wait([
            for (final i in imgs) _download(i['storage_path'] as String),
          ]);
          return projectFromRow(r, bytes.whereType<Uint8List>().toList());
        }(),
    ]);
  }

  Future<Uint8List?> _download(String path) async {
    try {
      final res = await http.get(Uri.parse(publicImageUrl(path)));
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insert(NewProject p) async {
    final row = projectToRow(p)
      ..['created_by'] = _c.auth.currentUser?.id;
    final inserted = await _c.from('projects').insert(row).select('id').single();
    p.id = inserted['id'] as String;
    try {
      await _saveChildren(p);
    } catch (_) {
      // ไม่ให้เหลือโครงการครึ่ง ๆ กลาง ๆ
      await delete(p);
      rethrow;
    }
  }

  @override
  Future<void> update(NewProject old, NewProject p) async {
    final id = old.id!;
    p.id = id;
    await _c.from('projects').update(projectToRow(p)).eq('id', id);
    await _deleteChildren(id);
    await _saveChildren(p);
  }

  @override
  Future<void> delete(NewProject p) async {
    final id = p.id;
    if (id == null) return;
    await _deleteChildren(id);
    await _c.from('projects').delete().eq('id', id);
  }

  Future<void> _saveChildren(NewProject p) async {
    final id = p.id!;
    if (p.units.isNotEmpty) {
      await _c.from('project_units').insert([
        for (final u in p.units) {...u.toJson(), 'project_id': id},
      ]);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < p.imageBytes.length; i++) {
      final bytes = p.imageBytes[i];
      final (ext, mime) = imageType(bytes);
      final path = '$id/${stamp}_$i.$ext';
      await _c.storage
          .from(kImageBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(contentType: mime),
          );
      rows.add({'project_id': id, 'storage_path': path, 'sort_order': i});
    }
    if (rows.isNotEmpty) await _c.from('project_images').insert(rows);
  }

  Future<void> _deleteChildren(String id) async {
    final imgs = await _c
        .from('project_images')
        .select('storage_path')
        .eq('project_id', id);
    final paths = [for (final i in imgs) i['storage_path'] as String];
    if (paths.isNotEmpty) {
      await _c.storage.from(kImageBucket).remove(paths);
    }
    await _c.from('project_images').delete().eq('project_id', id);
    await _c.from('project_units').delete().eq('project_id', id);
  }
}
