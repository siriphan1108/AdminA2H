import 'dart:typed_data';

import 'package:admin_a2h/models/project.dart';
import 'package:admin_a2h/services/project_store.dart';
import 'package:admin_a2h/services/supabase_projects.dart';
import 'package:flutter_test/flutter_test.dart';

NewProject _p({String name = 'Life Ari', String status = 'เปิดขาย'}) => NewProject(
  name: name,
  type: 'คอนโด',
  developer: 'A2',
  province: 'กรุงเทพมหานคร',
  district: 'พญาไท',
  subDistrict: 'สามเสนใน',
  address: 'ซอยอารีย์ 1',
  imageBytes: [Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])],
  facilities: const ['สระว่ายน้ำ'],
  units: const [ProjectUnit(unitNo: 'A1', bedrooms: 1, area: 30.5)],
  latitude: 13.78,
  longitude: 100.54,
  startPrice: 2500000,
  maxPrice: 5900000,
  downPaymentPercent: 10,
  commissionPercent: 3,
  commissionBase: 'ราคาขาย (สุทธิ)',
  saleStart: DateTime(2026, 12, 1),
  status: status,
  contactName: 'ฝ่ายขาย',
  contactPhone: '0800000000',
);

class _FakeRemote implements ProjectBackend {
  final rows = <String, NewProject>{};
  bool fail = false;
  var _n = 0;

  @override
  Future<List<NewProject>> loadAll() async => rows.values.toList();

  @override
  Future<void> insert(NewProject p) async {
    if (fail) throw Exception('network down');
    p.id = 'id${_n++}';
    rows[p.id!] = p;
  }

  @override
  Future<void> update(NewProject old, NewProject p) async {
    if (fail) throw Exception('network down');
    p.id = old.id;
    rows[p.id!] = p;
  }

  @override
  Future<void> delete(NewProject p) async => rows.remove(p.id);
}

void main() {
  test('project ↔ database row mapping keeps the important fields', () {
    final row = projectToRow(_p());
    expect(row['sale_status'], 'เปิดขาย');
    expect(row['visibility'], 'published');
    expect(row['sale_start'], '2026-12-01');
    expect(row['sub_district'], 'สามเสนใน');
    expect(row.containsKey('status'), isFalse); // คอลัมน์ชื่อ sale_status

    final back = projectFromRow({
      ...row,
      'id': 'uuid-1',
      'project_units': [
        {'unit_no': 'A1', 'bedrooms': 1, 'area': 30.5},
      ],
    }, const []);
    expect(back.id, 'uuid-1');
    expect(back.name, 'Life Ari');
    expect(back.status, 'เปิดขาย');
    expect(back.saleStart, DateTime(2026, 12, 1));
    expect(back.units.single.unitNo, 'A1');
    expect(imageType(_p().imageBytes.first).$1, 'png');
  });

  test('store uses the server: add/update/remove, failure keeps form data', () async {
    final remote = _FakeRemote();
    final store = ProjectStore.instance..useBackend(remote);
    await store.reload();

    final p = _p();
    await store.add(p);
    expect(p.id, isNotNull);
    expect(store.projects.single.name, 'Life Ari');

    final edited = _p(name: 'Life Ari 2');
    await store.update(p, edited);
    expect(remote.rows[p.id]!.name, 'Life Ari 2');

    remote.fail = true;
    await expectLater(store.add(_p(name: 'X')), throwsA(isA<ProjectSaveException>()));
    expect(store.projects.length, 1); // ไม่เพิ่มโครงการที่บันทึกไม่สำเร็จ
    remote.fail = false;

    await store.remove(edited);
    expect(store.projects, isEmpty);
    expect(remote.rows, isEmpty);
  });
}
