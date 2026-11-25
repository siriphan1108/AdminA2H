
import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/admin_auth.dart';
import '../services/backup_export.dart';
import '../services/project_store.dart';
import '../services/settings_store.dart';
import '../services/user_store.dart';
import '../theme/app_colors.dart';
import '../utils/download.dart';
import '../widgets/dashboard_header.dart';

/// หน้าตั้งค่าระบบ: การ์ด 6 หมวด กดแล้วเปิดหน้าต่างตั้งค่าของหมวดนั้น
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.username,
    required this.onLogout,
    this.onMenu,
  });

  final String username;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = SettingsStore.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          width: 520,
          backgroundColor: AppColors.navy,
        ),
      );
  }

  Future<void> _open(Widget dialog) async {
    final msg = await showDialog<String>(
      context: context,
      builder: (_) => dialog,
    );
    if (msg != null && mounted) _toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, VoidCallback)>[
      (
        Icons.person_rounded,
        'บัญชีผู้ดูแลระบบ',
        'จัดการข้อมูลผู้ดูแลระบบและเปลี่ยนรหัสผ่าน',
        () => _open(const _AccountDialog()),
      ),
      (
        Icons.apartment_rounded,
        'ข้อมูลบริษัท',
        'แก้ไขข้อมูลบริษัทและรายละเอียดการติดต่อ',
        () => _open(const _CompanyDialog()),
      ),
      (
        Icons.notifications_rounded,
        'การแจ้งเตือน',
        'ตั้งค่าการแจ้งเตือนต่าง ๆ ของระบบ',
        () => _open(const _NotificationsDialog()),
      ),
      (
        Icons.shield_rounded,
        'ความปลอดภัย',
        'ตั้งค่าความปลอดภัยและการเข้าสู่ระบบ',
        () => _open(const _SecurityDialog()),
      ),
      (
        Icons.storage_rounded,
        'จัดการข้อมูลระบบ',
        'สำรองข้อมูลและจัดการข้อมูลในระบบ',
        () => _open(const _DataDialog()),
      ),
      (
        Icons.info_rounded,
        'เกี่ยวกับระบบ',
        'ข้อมูลเวอร์ชันและรายละเอียดระบบ',
        () => _open(const _AboutDialog()),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        DashboardHeader(
          title: 'ตั้งค่าระบบ',
          subtitle: 'จัดการการตั้งค่าต่าง ๆ ของระบบ',
          icon: Icons.settings_rounded,
          username: widget.username,
          onMenu: widget.onMenu,
          onLogout: widget.onLogout,
          notificationCount: 3,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 22.0;
            final cols = c.maxWidth >= 900 ? 2 : 1;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (icon, title, sub, onTap) in items)
                  SizedBox(
                    width: w,
                    child: _SettingCard(
                      icon: icon,
                      title: title,
                      subtitle: sub,
                      onTap: onTap,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// การ์ดหมวดตั้งค่า
// ---------------------------------------------------------------------------

class _SettingCard extends StatefulWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<_SettingCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _hover ? const Color(0xFFBFD3F5) : Colors.white,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: _hover ? 0.12 : 0.07),
              blurRadius: _hover ? 28 : 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
              child: Row(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEBF1FC),
                    ),
                    child: Icon(widget.icon, size: 54, color: AppColors.blue),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF4A5B7D),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 34,
                    color: AppColors.navy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// โครงหน้าต่างตั้งค่า
// ---------------------------------------------------------------------------

class _SettingsShell extends StatelessWidget {
  const _SettingsShell({
    required this.icon,
    required this.title,
    required this.children,
    this.onSave,
    this.formKey,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  /// null = ไม่มีปุ่มบันทึก (มีแต่ปุ่มปิด)
  final VoidCallback? onSave;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF1FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.blue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
                child: formKey == null ? body : Form(key: formKey, child: body),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(onSave == null ? 'ปิด' : 'ยกเลิก'),
                  ),
                  if (onSave != null) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(130, 46),
                      ),
                      child: const Text('บันทึก'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _deco(String label, IconData icon, {String? helper}) =>
    InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, color: AppColors.hint),
      filled: true,
      fillColor: const Color(0xFFF6F9FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 10),
  child: Text(
    text,
    style: const TextStyle(
      color: AppColors.navy,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Widget _note(String text) => Container(
  margin: const EdgeInsets.only(top: 4, bottom: 8),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF4E5),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        Icons.info_outline_rounded,
        size: 20,
        color: Color(0xFFB86E00),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF8A5300), fontSize: 13),
        ),
      ),
    ],
  ),
);

String? _emailOrEmpty(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
      ? null
      : 'รูปแบบอีเมลไม่ถูกต้อง';
}

/// ฟิลด์ข้อความที่ผูกกับ key ใน SettingsStore
class _Field {
  const _Field(
    this.key,
    this.label,
    this.icon, {
    this.keyboard,
    this.validator,
    this.maxLines = 1,
  });
  final String key;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final int maxLines;
}

mixin _TextFieldsMixin<T extends StatefulWidget> on State<T> {
  List<_Field> get fields;
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> ctrls = {
    for (final f in fields)
      f.key: TextEditingController(text: SettingsStore.instance.text(f.key)),
  };

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(_Field f) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: ctrls[f.key],
      keyboardType: f.keyboard,
      maxLines: f.maxLines,
      textInputAction: f.maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: _deco(f.label, f.icon),
      validator: f.validator,
    ),
  );

  Map<String, Object> textValues() => {
    for (final e in ctrls.entries) e.key: e.value.text.trim(),
  };
}

// ---------------------------------------------------------------------------
// 1. บัญชีผู้ดูแลระบบ
// ---------------------------------------------------------------------------

class _AccountDialog extends StatelessWidget {
  const _AccountDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF1FC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'บัญชีผู้ดูแลระบบ',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: AppColors.blue,
                unselectedLabelColor: AppColors.navy,
                indicatorColor: AppColors.blue,
                labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'บัญชีของฉัน'),
                  Tab(text: 'ผู้ดูแลระบบทั้งหมด'),
                ],
              ),
              const Flexible(
                child: SizedBox(
                  height: 600,
                  child: TabBarView(children: [_MyAccountTab(), _AdminsTab()]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แท็บ "บัญชีของฉัน": แก้ชื่อ เบอร์ และเปลี่ยนรหัสผ่าน (บัญชี Supabase)
class _MyAccountTab extends StatefulWidget {
  const _MyAccountTab();

  @override
  State<_MyAccountTab> createState() => _MyAccountTabState();
}

class _MyAccountTabState extends State<_MyAccountTab> {
  final _auth = AdminAuth.instance;
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _auth.current?.name);
  late final _phone = TextEditingController(text: _auth.current?.phone);
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _currentPw, _newPw, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _changingPassword =>
      _currentPw.text.isNotEmpty ||
      _newPw.text.isNotEmpty ||
      _confirm.text.isNotEmpty;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      if (_changingPassword) {
        await _auth.changePassword(_currentPw.text, _newPw.text);
      }
      await _auth.updateProfile(name: _name.text, phone: _phone.text);
    } on AuthException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
      return;
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'บันทึกไม่สำเร็จ: $e';
      });
      return;
    }
    nav.pop(
      _changingPassword
          ? 'บันทึกข้อมูลและเปลี่ยนรหัสผ่านแล้ว'
          : 'บันทึกข้อมูลบัญชีแล้ว',
    );
  }

  Widget _pw(TextEditingController c, String label, String? Function(String?) v) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          obscureText: !_show,
          onChanged: (_) => setState(() {}),
          decoration: _deco(label, Icons.lock_outline_rounded),
          validator: v,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = _auth.current;
    if (me == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบ'));
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: AppColors.hint,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          me.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _AdminRoleChip(me.role),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: _name,
                      decoration: _deco('ชื่อที่แสดง *', Icons.badge_outlined),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: _deco('เบอร์โทรศัพท์', Icons.phone_outlined),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('เปลี่ยนรหัสผ่าน')),
                      TextButton.icon(
                        onPressed: () => setState(() => _show = !_show),
                        icon: Icon(
                          _show
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        label: Text(_show ? 'ซ่อนรหัส' : 'แสดงรหัส'),
                      ),
                    ],
                  ),
                  _pw(
                    _currentPw,
                    'รหัสผ่านปัจจุบัน',
                    (v) => _changingPassword && (v ?? '').isEmpty
                        ? 'กรุณากรอกรหัสผ่านปัจจุบัน'
                        : null,
                  ),
                  _pw(
                    _newPw,
                    'รหัสผ่านใหม่ (อย่างน้อย 8 ตัว)',
                    (v) => _changingPassword
                        ? AdminAuth.validatePassword(v)
                        : null,
                  ),
                  _pw(
                    _confirm,
                    'ยืนยันรหัสผ่านใหม่',
                    (v) => _changingPassword && v != _newPw.text
                        ? 'รหัสผ่านไม่ตรงกัน'
                        : null,
                  ),
                  if (_error != null) _errorText(_error!),
                ],
              ),
            ),
          ),
        ),
        _footer(context, onSave: _saving ? null : _save),
      ],
    );
  }
}

Widget _errorText(String msg) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 8),
  child: Text(
    msg,
    style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
  ),
);

Widget _footer(BuildContext context, {VoidCallback? onSave, String save = 'บันทึก'}) =>
    Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(130, 46),
                ),
                child: Text(save),
              ),
            ],
          ),
        ),
      ],
    );

class _AdminRoleChip extends StatelessWidget {
  const _AdminRoleChip(this.role);
  final String role;

  @override
  Widget build(BuildContext context) {
    final owner = role == kRoleOwner;
    final fg = owner ? const Color(0xFF6B3FD1) : AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: owner ? const Color(0xFFEDE5FD) : const Color(0xFFE3EEFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owner ? Icons.workspace_premium_rounded : Icons.shield_outlined,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            roleLabel(role),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showError(BuildContext context, Object e) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ทำรายการไม่ได้'),
      content: Text(e is AuthException ? e.message : '$e'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );
}

/// แท็บ "ผู้ดูแลระบบทั้งหมด": รายชื่อจาก Supabase — ผู้ดูแลหลักเพิ่ม/ถอดสิทธิ์ได้
class _AdminsTab extends StatefulWidget {
  const _AdminsTab();

  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  final _auth = AdminAuth.instance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.refreshAdmins();
    } catch (e) {
      _error = 'โหลดรายชื่อไม่สำเร็จ: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(done), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) await _showError(context, e);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        final me = _auth.current;
        final owner = me?.isOwner ?? false;
        final admins = _auth.admins;
        return ListView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loading ? 'กำลังโหลด...' : 'ผู้ดูแลระบบ ${admins.length} คน',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'โหลดใหม่',
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (owner)
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _AddAdminDialog(),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('เพิ่มผู้ดูแลระบบ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
              ],
            ),
            if (!owner)
              _note(
                'เฉพาะผู้ดูแลหลักเท่านั้นที่เพิ่ม เปลี่ยนสิทธิ์ หรือถอดสิทธิ์ผู้ดูแลคนอื่นได้',
              ),
            if (_error != null) _errorText(_error!),
            const SizedBox(height: 8),
            for (final a in admins) ...[
              const Divider(height: 1, color: Color(0xFFE8EEF8)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.navy,
                      child: Text(
                        a.displayName.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.id == me?.id
                                ? '${a.displayName} (คุณ)'
                                : a.displayName,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [a.email, if (a.phone.isNotEmpty) a.phone].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.hint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AdminRoleChip(a.role),
                    SizedBox(
                      width: 44,
                      child: owner && a.id != me?.id
                          ? PopupMenuButton<String>(
                              tooltip: 'จัดการ',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (v) async {
                                switch (v) {
                                  case 'role':
                                    await _run(
                                      () => _auth.setRole(
                                        a.email,
                                        a.isOwner ? kRoleAdmin : kRoleOwner,
                                      ),
                                    );
                                  case 'reset':
                                    await _run(
                                      () => _auth.sendPasswordReset(a.email),
                                      done: 'ส่งอีเมลตั้งรหัสผ่านใหม่ไปที่ ${a.email} แล้ว',
                                    );
                                  case 'remove':
                                    if (await _confirm(
                                      'ถอดสิทธิ์ผู้ดูแลระบบ?',
                                      '"${a.displayName}" จะเข้าเว็บแอดมินไม่ได้อีก '
                                          '(บัญชียังใช้แอป HomeConnect ได้ตามปกติ)',
                                    )) {
                                      await _run(
                                        () => _auth.setRole(a.email, kRoleUser),
                                      );
                                    }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'role',
                                  child: Text(
                                    a.isOwner
                                        ? 'เปลี่ยนเป็นแอดมิน'
                                        : 'เปลี่ยนเป็นผู้ดูแลหลัก',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Text('ส่งอีเมลตั้งรหัสผ่านใหม่'),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    'ถอดสิทธิ์ผู้ดูแลระบบ',
                                    style: TextStyle(color: Color(0xFFE53935)),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// เพิ่มผู้ดูแลระบบด้วยอีเมล (คนนั้นต้องมีบัญชีอยู่แล้ว)
class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog();

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String _role = kRoleAdmin;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await AdminAuth.instance.setRole(_email.text, _role);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e is AuthException ? e.message : '$e';
      });
      return;
    }
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      icon: Icons.person_add_alt_1_rounded,
      title: 'เพิ่มผู้ดูแลระบบ',
      formKey: _formKey,
      onSave: _save,
      children: [
        const SizedBox(height: 6),
        TextFormField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          onFieldSubmitted: (_) => _save(),
          decoration: _deco('อีเมลของบัญชี *', Icons.mail_outline_rounded),
          validator: (v) => (v ?? '').trim().isEmpty
              ? 'กรุณากรอกอีเมล'
              : _emailOrEmpty(v),
        ),
        const SizedBox(height: 18),
        _sectionTitle('สิทธิ์'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final r in kAdminRoles)
              ButtonSegment(value: r, label: Text(roleLabel(r))),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        const SizedBox(height: 6),
        Text(
          _role == kRoleOwner
              ? 'ผู้ดูแลหลัก: ทำได้ทุกอย่าง รวมถึงเพิ่ม/ถอดสิทธิ์ผู้ดูแลคนอื่น'
              : 'แอดมิน: จัดการโครงการ ผู้ใช้ รายงาน และตั้งค่าได้ แต่จัดการผู้ดูแลคนอื่นไม่ได้',
          style: const TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const SizedBox(height: 12),
        _note(
          'คนนั้นต้องมีบัญชีก่อน — สมัครในแอป HomeConnect หรือให้สร้างใน Supabase '
          '(Authentication › Users › Add user) แล้วค่อยเพิ่มสิทธิ์ที่นี่ '
          'เขาจะเข้าเว็บแอดมินด้วยอีเมลและรหัสผ่านของบัญชีนั้น',
        ),
        if (_error != null) _errorText(_error!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. ข้อมูลบริษัท
// ---------------------------------------------------------------------------

class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog();

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> with _TextFieldsMixin {
  @override
  final fields = const [
    _Field(
      'company_name',
      'ชื่อบริษัท *',
      Icons.apartment_rounded,
      validator: _required,
    ),
    _Field('company_address', 'ที่อยู่', Icons.place_outlined, maxLines: 3),
    _Field(
      'company_phone',
      'เบอร์โทรศัพท์',
      Icons.phone_outlined,
      keyboard: TextInputType.phone,
    ),
    _Field(
      'company_email',
      'อีเมล',
      Icons.mail_outline_rounded,
      keyboard: TextInputType.emailAddress,
      validator: _emailOrEmpty,
    ),
    _Field('company_line', 'LINE ID', Icons.chat_outlined),
    _Field('company_facebook', 'Facebook', Icons.facebook_rounded),
    _Field(
      'company_website',
      'เว็บไซต์',
      Icons.language_rounded,
      keyboard: TextInputType.url,
    ),
  ];

  static String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อบริษัท' : null;

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final nav = Navigator.of(context);
    await SettingsStore.instance.setAll(textValues());
    nav.pop('บันทึกข้อมูลบริษัทแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      icon: Icons.apartment_rounded,
      title: 'ข้อมูลบริษัท',
      formKey: formKey,
      onSave: _save,
      children: [const SizedBox(height: 6), for (final f in fields) field(f)],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. การแจ้งเตือน
// ---------------------------------------------------------------------------

class _NotificationsDialog extends StatefulWidget {
  const _NotificationsDialog();

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  static const _items = [
    (
      'notify_new_user',
      'มีผู้ใช้สมัครสมาชิกใหม่',
      'แจ้งเมื่อมีผู้ใช้สมัครผ่านแอป HomeConnect',
    ),
    ('notify_like', 'มีคนกดใจโครงการ', 'แจ้งเมื่อโครงการถูกกดใจ ❤ ในแอป'),
    (
      'notify_promo_end',
      'โปรโมชั่นใกล้หมดอายุ',
      'แจ้งล่วงหน้า 7 วันก่อนวันสิ้นสุดโปรโมชั่นของโครงการ',
    ),
    (
      'notify_weekly_email',
      'อีเมลสรุปรายสัปดาห์',
      'ส่งสรุปยอดเข้าชมและความสนใจทางอีเมลทุกวันจันทร์',
    ),
  ];

  late final Map<String, bool> _on = {
    for (final (k, _, _) in _items) k: SettingsStore.instance.flag(k),
  };

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      icon: Icons.notifications_rounded,
      title: 'การแจ้งเตือน',
      onSave: () async {
        final nav = Navigator.of(context);
        await SettingsStore.instance.setAll(_on);
        nav.pop('บันทึกการตั้งค่าการแจ้งเตือนแล้ว');
      },
      children: [
        for (final (k, title, sub) in _items)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _on[k]!,
            onChanged: (v) => setState(() => _on[k] = v),
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(sub),
          ),
        _note(
          'การแจ้งเตือนจะเริ่มส่งจริงเมื่อเชื่อมแอป HomeConnect กับเซิร์ฟเวอร์แล้ว',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. ความปลอดภัย
// ---------------------------------------------------------------------------

class _SecurityDialog extends StatefulWidget {
  const _SecurityDialog();

  @override
  State<_SecurityDialog> createState() => _SecurityDialogState();
}

class _SecurityDialogState extends State<_SecurityDialog> {
  final _s = SettingsStore.instance;
  late int _logout = _s.number('auto_logout_minutes');
  late int _attempts = _s.number('max_login_attempts');
  late bool _twoFactor = _s.flag('two_factor');

  Widget _dropdown(
    String label,
    IconData icon,
    int value,
    List<(int, String)> options,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: _deco(label, icon),
        items: [
          for (final (v, t) in options)
            DropdownMenuItem(value: v, child: Text(t)),
        ],
        onChanged: (v) => setState(() => onChanged(v!)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsShell(
      icon: Icons.shield_rounded,
      title: 'ความปลอดภัย',
      onSave: () async {
        final nav = Navigator.of(context);
        await _s.setAll({
          'auto_logout_minutes': _logout,
          'max_login_attempts': _attempts,
          'two_factor': _twoFactor,
        });
        nav.pop('บันทึกการตั้งค่าความปลอดภัยแล้ว');
      },
      children: [
        const SizedBox(height: 6),
        _dropdown(
          'ออกจากระบบอัตโนมัติเมื่อไม่ได้ใช้งาน',
          Icons.timer_outlined,
          _logout,
          const [
            (15, '15 นาที'),
            (30, '30 นาที'),
            (60, '1 ชั่วโมง'),
            (0, 'ไม่ออกอัตโนมัติ'),
          ],
          (v) => _logout = v,
        ),
        _dropdown(
          'ล็อกบัญชีเมื่อใส่รหัสผิดเกิน',
          Icons.lock_clock_outlined,
          _attempts,
          const [(3, '3 ครั้ง'), (5, '5 ครั้ง'), (10, '10 ครั้ง')],
          (v) => _attempts = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _twoFactor,
          onChanged: (v) => setState(() => _twoFactor = v),
          title: const Text(
            'ยืนยันตัวตนสองขั้นตอน (2FA)',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text('ขอรหัส OTP ทางอีเมลทุกครั้งที่เข้าสู่ระบบ'),
        ),
        _note(
          'ออกจากระบบอัตโนมัติและการล็อกเมื่อใส่รหัสผิดใช้งานได้แล้ว '
          'ส่วนการยืนยันตัวตนสองขั้นตอนต้องรอเชื่อมเซิร์ฟเวอร์ส่งอีเมล',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. จัดการข้อมูลระบบ
// ---------------------------------------------------------------------------

class _DataDialog extends StatefulWidget {
  const _DataDialog();

  @override
  State<_DataDialog> createState() => _DataDialogState();
}

class _DataDialogState extends State<_DataDialog> {
  final _projects = ProjectStore.instance;
  final _users = UserStore.instance;

  @override
  void initState() {
    super.initState();
    _projects.load();
    _users.load();
  }

  bool _exporting = false;

  /// ดาวน์โหลดไฟล์ Excel (.xlsx) — เปิดใน Excel หรืออัปโหลดเข้า Google Sheets ได้
  Future<void> _downloadExcel() async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildBackupXlsx(
        projects: _projects.projects,
        users: _users.users,
      );
      await downloadBytes(
        bytes,
        backupFileName(),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        Navigator.pop(context, 'ดาวน์โหลดไฟล์สำรองข้อมูล (Excel) แล้ว');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('สร้างไฟล์ไม่สำเร็จ: $e')));
      }
    }
  }

  Future<bool> _confirm(String what) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ลบ$whatทั้งหมด?'),
        content: Text(
          'ข้อมูล$whatทั้งหมดในเบราว์เซอร์นี้จะถูกลบ และกู้คืนไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearProjects() async {
    if (!await _confirm('โครงการ')) return;
    for (final p in List<NewProject>.of(_projects.projects)) {
      await _projects.remove(p);
    }
    if (mounted) Navigator.pop(context, 'ลบโครงการทั้งหมดแล้ว');
  }

  Future<void> _clearUsers() async {
    if (!await _confirm('ผู้ใช้งาน')) return;
    for (final u in List.of(_users.users)) {
      await _users.remove(u);
    }
    if (mounted) Navigator.pop(context, 'ลบผู้ใช้งานทั้งหมดแล้ว');
  }

  Widget _stat(IconData icon, String label, int n) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.hint)),
          ),
          Text(
            '$n',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _action(
    IconData icon,
    String title,
    String sub,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFE53935) : AppColors.blue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: danger ? color : AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(sub),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: onTap != null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_projects, _users]),
      builder: (context, _) => _SettingsShell(
        icon: Icons.storage_rounded,
        title: 'จัดการข้อมูลระบบ',
        children: [
          Row(
            children: [
              _stat(
                Icons.home_work_rounded,
                'โครงการ',
                _projects.projects.length,
              ),
              const SizedBox(width: 12),
              _stat(Icons.groups_rounded, 'ผู้ใช้งาน', _users.users.length),
            ],
          ),
          const SizedBox(height: 10),
          _action(
            _exporting ? Icons.hourglass_top_rounded : Icons.table_view_rounded,
            _exporting ? 'กำลังสร้างไฟล์...' : 'ดาวน์โหลดไฟล์สำรอง (Excel)',
            'ตารางโครงการพร้อมรูป ยูนิต และผู้ใช้งาน — เปิดใน Excel หรือ Google Sheets ได้',
            _exporting ? null : _downloadExcel,
          ),
          const Divider(),
          _action(
            Icons.delete_sweep_outlined,
            'ลบโครงการทั้งหมด',
            'ล้างโครงการทุกโครงการในเบราว์เซอร์นี้',
            _projects.projects.isEmpty ? null : _clearProjects,
            danger: true,
          ),
          _action(
            Icons.person_remove_outlined,
            'ลบผู้ใช้งานทั้งหมด',
            'ล้างรายชื่อผู้ใช้งานในเบราว์เซอร์นี้',
            _users.users.isEmpty ? null : _clearUsers,
            danger: true,
          ),
          _note(
            'ข้อมูลทั้งหมดเก็บอยู่ในเบราว์เซอร์เครื่องนี้เท่านั้น '
            'ถ้าล้างข้อมูลเบราว์เซอร์ ข้อมูลจะหายด้วย',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. เกี่ยวกับระบบ
// ---------------------------------------------------------------------------

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('ชื่อระบบ', 'HomeConnect Admin Panel'),
      ('บริษัท', 'A2 Property'),
      ('เวอร์ชัน', '1.0.0 (build 1)'),
      ('แพลตฟอร์ม', 'Flutter Web'),
      ('การเก็บข้อมูล', 'เบราว์เซอร์ (localStorage) — ยังไม่เชื่อมเซิร์ฟเวอร์'),
      ('แอปที่เกี่ยวข้อง', 'HomeConnect (แอปสำหรับลูกค้า)'),
    ];
    return _SettingsShell(
      icon: Icons.info_rounded,
      title: 'เกี่ยวกับระบบ',
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(k, style: const TextStyle(color: AppColors.hint)),
                ),
                Expanded(
                  child: Text(
                    v,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
