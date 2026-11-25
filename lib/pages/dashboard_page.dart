import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/admin_auth.dart';
import '../services/project_store.dart';
import '../services/settings_store.dart';
import '../services/user_store.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/panel.dart';
import '../widgets/stat_card.dart';
import '../widgets/usage_line_chart.dart';
import 'add_project_page.dart';
import 'login_page.dart';
import 'manage_projects_page.dart';
import 'manage_users_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.username = 'Admin'});

  final String username;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selected = 0;
  int _addFormVersion = 0;
  NewProject? _editing; // โครงการที่กำลังแก้ไข (ใช้หน้าเดียวกับเพิ่มโครงการ)

  static const _addIndex = 1;
  static const _manageIndex = 2;
  static const _usersIndex = 3;
  static const _reportsIndex = 4;

  final _auth = AdminAuth.instance;
  Timer? _idle;

  /// ชื่อที่แสดงของแอดมินที่เข้าสู่ระบบอยู่
  String get _username => _auth.current?.name ?? widget.username;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    SettingsStore.instance.load().then((_) => _resetIdle());
  }

  @override
  void dispose() {
    _idle?.cancel();
    _auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  /// ออกจากระบบอัตโนมัติเมื่อไม่ได้ใช้งานตามเวลาที่ตั้งไว้ (ตั้งค่าระบบ › ความปลอดภัย)
  void _resetIdle() {
    _idle?.cancel();
    final minutes = SettingsStore.instance.number('auto_logout_minutes');
    if (minutes <= 0 || !mounted) return;
    _idle = Timer(Duration(minutes: minutes), () => _logout(idle: true));
  }

  void _select(int index) {
    setState(() {
      _selected = index;
      _editing = null;
      _addFormVersion++;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout({bool idle = false}) async {
    _idle?.cancel();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _auth.logout();
    nav.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
    if (idle) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ออกจากระบบอัตโนมัติเพราะไม่ได้ใช้งานนาน'),
          behavior: SnackBarBehavior.floating,
          width: 460,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final sidebar = AdminSidebar(
          // ระหว่างแก้ไขโครงการ ให้เมนู "จัดการโครงการ" ยังติดไฮไลต์
          selected: _editing != null ? _manageIndex : _selected,
          onSelect: _select,
          onLogout: _logout,
        );
        final onMenu = wide
            ? null
            : () => _scaffoldKey.currentState?.openDrawer();

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _resetIdle(),
          onPointerHover: (_) => _resetIdle(),
          child: Scaffold(
            key: _scaffoldKey,
            drawer: wide ? null : Drawer(width: 260, child: sidebar),
            body: Row(
              children: [
                if (wide) SizedBox(width: 250, child: sidebar),
                Expanded(
                  child: DecoratedBox(
                    key: pageBackgroundKey,
                    decoration: const BoxDecoration(
                      gradient: AppColors.pageGradient,
                    ),
                    child: switch (_selected) {
                      0 => _DashboardHome(
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                      ),
                      _addIndex => AddProjectPage(
                        // เปลี่ยน key = ฟอร์มใหม่ (หลังบันทึก/ล้างฟอร์ม/เริ่มแก้ไข)
                        key: ValueKey(_addFormVersion),
                        editing: _editing,
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                        // บันทึกแล้ว: ไปหน้าจัดการโครงการ
                        onSaved: () => setState(() {
                          _editing = null;
                          _addFormVersion++;
                          _selected = _manageIndex;
                        }),
                        // ล้างฟอร์ม / ยกเลิกการแก้ไข
                        onDone: () => setState(() {
                          if (_editing != null) _selected = _manageIndex;
                          _editing = null;
                          _addFormVersion++;
                        }),
                      ),
                      _manageIndex => ManageProjectsPage(
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                        onAdd: () => _select(_addIndex),
                        onEdit: (p) => setState(() {
                          _editing = p;
                          _addFormVersion++;
                          _selected = _addIndex;
                        }),
                      ),
                      _usersIndex => ManageUsersPage(
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                      ),
                      _reportsIndex => ReportsPage(
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                      ),
                      _ => SettingsPage(
                        username: _username,
                        onMenu: onMenu,
                        onLogout: _logout,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard home
// ---------------------------------------------------------------------------

// Chart data is empty until it comes from the backend. Fill these in
// (one x-label per value) and the lines will be drawn automatically.
const _chartDays = <String>[];
const _visits = <double>[];
const _searches = <double>[];

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.username,
    required this.onMenu,
    required this.onLogout,
  });

  final String username;
  final VoidCallback? onMenu;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        DashboardHeader(
          title: 'ยินดีต้อนรับสู่ระบบผู้ดูแล',
          subtitle: 'HomeConnect Admin Panel',
          username: username,
          onMenu: onMenu,
          onLogout: onLogout,
          notificationCount: 3,
        ),
        const SizedBox(height: 16),
        const _StatGrid(),
        const SizedBox(height: 20),
        const _UsageCard(),
      ],
    );
  }
}

/// การ์ดตัวเลขบนหน้าหลัก — นับจากข้อมูลจริงในระบบ
class _StatGrid extends StatefulWidget {
  const _StatGrid();

  @override
  State<_StatGrid> createState() => _StatGridState();
}

class _StatGridState extends State<_StatGrid> {
  final _projects = ProjectStore.instance;
  final _users = UserStore.instance;

  @override
  void initState() {
    super.initState();
    _projects.load();
    _users.load();
  }

  static String _comma(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  @override
  Widget build(BuildContext context) {
    const gap = 20.0;
    return ListenableBuilder(
      listenable: Listenable.merge([_projects, _users]),
      builder: (context, _) {
        final projects = _projects.projects;
        final units = projects.fold<int>(0, (a, p) => a + p.units.length);
        final stats = [
          (Icons.home_work_rounded, projects.length, 'โครงการทั้งหมด'),
          (Icons.apartment_rounded, units, 'ยูนิตทั้งหมด'),
          (Icons.groups_rounded, _users.users.length, 'ผู้ใช้งานทั้งหมด'),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 760 ? 3 : 1;
            final cardWidth = (w - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (icon, value, label) in stats)
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      icon: icon,
                      value: _comma(value),
                      label: label,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    this.underline = false,
  });

  final IconData icon;
  final String title;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
    return Row(
      children: [
        Icon(icon, color: AppColors.blue, size: 24),
        const SizedBox(width: 10),
        if (underline)
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.blue, width: 2.5),
              ),
            ),
            child: text,
          )
        else
          text,
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard();

  @override
  Widget build(BuildContext context) {
    return const Panel(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.campaign_rounded,
            title: 'ภาพรวมการใช้งาน',
            underline: true,
          ),
          Divider(height: 1, color: Color(0xFFE3EAF6)),
          SizedBox(height: 16),
          UsageLineChart(
            xLabels: _chartDays,
            series: [
              ChartSeries(
                label: 'การเข้าชม',
                values: _visits,
                color: AppColors.blue,
                primary: true,
              ),
              ChartSeries(
                label: 'การค้นหา',
                values: _searches,
                color: Color(0xFF9DBDF2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
