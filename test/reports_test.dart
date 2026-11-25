import 'dart:typed_data';

import 'package:admin_a2h/models/project.dart';
import 'package:admin_a2h/pages/reports_page.dart';
import 'package:admin_a2h/services/like_stats.dart';
import 'package:admin_a2h/services/project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NewProject _p(String type) => NewProject(
  name: 'P $type',
  type: type,
  developer: 'A2',
  province: 'กรุงเทพมหานคร',
  district: 'บางนา',
  address: 'x',
  imageBytes: <Uint8List>[],
  startPrice: 1000000,
  downPaymentPercent: 10,
  commissionPercent: 3,
  commissionBase: 'ราคาขาย (สุทธิ)',
  status: 'เปิดขาย',
  contactName: 'a',
  contactPhone: '0812345678',
);

void main() {
  testWidgets('reports: 3 tabs (no ยอดขาย), type share from saved projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore.instance;
    await tester.runAsync(() async {
      for (final p in [...store.projects]) {
        await store.remove(p);
      }
      for (final t in ['คอนโด', 'คอนโด', 'คอนโด', 'บ้านเดี่ยว']) {
        await store.add(_p(t));
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportsPage(username: 'Admin', onLogout: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ภาพรวม'), findsOneWidget);
    expect(find.text('ยอดเข้าชม'), findsOneWidget);
    expect(find.text('ความสนใจ'), findsOneWidget);
    expect(find.text('ยอดขาย'), findsNothing);

    expect(find.text('75%'), findsOneWidget); // คอนโด 3/4
    expect(find.text('25%'), findsOneWidget); // บ้านเดี่ยว 1/4
    expect(find.text('พูลวิลล่า'), findsOneWidget); // ทุกประเภทจากฟอร์ม

    // ความสนใจ = ยอดกดใจจากแอป
    await tester.tap(find.text('ความสนใจ'));
    await tester.pump();
    expect(find.text('โครงการที่ถูกกดใจมากที่สุด'), findsOneWidget);
    expect(find.text('ยังไม่มีการกดใจ'), findsOneWidget);

    LikeStats.instance.setAll({'P บ้านเดี่ยว': 7, 'P คอนโด': 3});
    await tester.pump();
    expect(find.text('รวม 16 ครั้ง'), findsOneWidget); // 3 คอนโด x3 + 7
    expect(find.text('7 ครั้ง'), findsOneWidget); // บ้านเดี่ยว
    expect(find.text('9 ครั้ง'), findsOneWidget); // คอนโด
    LikeStats.instance.setAll({});
  });
}
