import 'dart:typed_data';

import 'package:admin_a2h/models/project.dart';
import 'package:admin_a2h/pages/manage_projects_page.dart';
import 'package:admin_a2h/services/project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

NewProject _project(
  String name,
  String status, {
  String district = 'คลองเตย',
}) => NewProject(
  name: name,
  type: 'คอนโด',
  developer: 'A2',
  province: 'กรุงเทพมหานคร',
  district: district,
  address: 'ถนนสุขุมวิท',
  imageBytes: <Uint8List>[],
  startPrice: 2000000,
  downPaymentPercent: 10,
  commissionPercent: 3,
  commissionBase: 'ราคาขาย (สุทธิ)',
  status: status,
  contactName: 'คุณเอ',
  contactPhone: '0812345678',
);

void main() {
  testWidgets('lists saved projects, searches, opens edit and deletes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = ProjectStore.instance;
    await tester.runAsync(() async {
      await store.add(_project('Plum Condo', 'ปิดการขาย', district: 'บางนา'));
      await store.add(_project('Life Sukhumvit 62', 'เปิดขาย'));
    });

    NewProject? edited;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageProjectsPage(
            username: 'Admin',
            onLogout: () {},
            onAdd: () {},
            onEdit: (p) => edited = p,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Life Sukhumvit 62'), findsOneWidget);
    expect(find.text('Plum Condo'), findsOneWidget);
    expect(find.text('คลองเตย, กรุงเทพฯ'), findsOneWidget);
    expect(find.text('เปิดขาย'), findsOneWidget);

    // search
    await tester.enterText(find.byType(TextField), 'plum');
    await tester.pump();
    expect(find.text('Life Sukhumvit 62'), findsNothing);
    expect(find.text('Plum Condo'), findsOneWidget);

    // edit
    await tester.tap(find.byTooltip('แก้ไข'));
    expect(edited?.name, 'Plum Condo');

    // delete
    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบโครงการ'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Plum Condo'), findsNothing);
    expect(store.projects.map((p) => p.name), ['Life Sukhumvit 62']);
  });
}
