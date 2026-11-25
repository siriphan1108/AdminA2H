import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_user.dart';
import '../services/user_store.dart';
import '../theme/app_colors.dart';
import '../widgets/thai_date_picker.dart';
import '../widgets/panel.dart';

/// หน้าจัดการผู้ใช้งาน: ตารางผู้ใช้ ค้นหา กรองประเภท/สถานะ เพิ่ม แก้ไข ลบ
class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({
    super.key,
    required this.username,
    required this.onLogout,
    this.onMenu,
  });

  final String username;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  static const _perPage = 10;
  static const _red = Color(0xFFE53935);

  final _store = UserStore.instance;
  final _searchCtrl = TextEditingController();
  String? _role; // null = ทุกประเภท
  String? _status; // null = ทุกสถานะ
  DateTimeRange? _range; // null = ทุกช่วงวันที่ (กรองตามวันที่สมัคร)
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUser> _visible() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _store.users.where((u) {
      if (_role != null && u.role != _role) return false;
      if (_status != null && u.status != _status) return false;
      if (_range != null) {
        final d = DateUtils.dateOnly(u.createdAt);
        if (d.isBefore(_range!.start) || d.isAfter(_range!.end)) return false;
      }
      if (q.isEmpty) return true;
      return [
        u.name,
        u.email,
        u.phone,
        u.phone.replaceAll('-', ''),
      ].any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          width: 460,
          backgroundColor: AppColors.navy,
        ),
      );
  }

  Future<void> _openForm(AdminUser user) async {
    final result = await showDialog<AdminUser>(
      context: context,
      builder: (_) => _UserFormDialog(user: user, store: _store),
    );
    if (result == null || !mounted) return;
    await _store.update(user, result);
    _toast('บันทึกการแก้ไข "${result.name}" แล้ว');
  }

  Future<void> _confirmDelete(AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบผู้ใช้งาน?'),
        content: Text('ต้องการลบ "${u.name}" ใช่ไหม ลบแล้วกู้คืนไม่ได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบผู้ใช้'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.remove(u);
    if (mounted) _toast('ลบ "${u.name}" แล้ว');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageTitle(),
          const SizedBox(height: 20),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final all = _visible();
                final pages = (all.length / _perPage).ceil().clamp(1, 9999);
                if (_page >= pages) _page = pages - 1;
                final start = _page * _perPage;
                final pageItems = all.skip(start).take(_perPage).toList();
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(),
                      const SizedBox(height: 16),
                      Panel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _table(pageItems, offset: start),
                            const Divider(height: 1, color: Color(0xFFE8EEF8)),
                            _footer(pages, all.length),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------- toolbar ---------------------------------

  Widget _toolbar() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE5F3)),
    );
    final search = TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() => _page = 0),
      decoration: InputDecoration(
        hintText: 'ค้นหาจากชื่อ, อีเมล หรือเบอร์โทรศัพท์...',
        hintStyle: const TextStyle(color: AppColors.hint),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.hint),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้น',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _page = 0;
                }),
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
      ),
    );

    final filters = [
      _menuChip(
        value: _status,
        allLabel: 'สถานะทั้งหมด',
        options: kUserStatuses,
        onSelected: (v) => setState(() {
          _status = v;
          _page = 0;
        }),
      ),
      _menuChip(
        value: _role,
        allLabel: 'ประเภทผู้ใช้ทั้งหมด',
        options: kUserRoles,
        onSelected: (v) => setState(() {
          _role = v;
          _page = 0;
        }),
      ),
      _dateRangeChip(),
    ];

    return Panel(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) => _toolbarLayout(c, search, filters),
      ),
    );
  }

  Widget _toolbarLayout(BoxConstraints c, Widget search, List<Widget> filters) {
    if (c.maxWidth >= 900) {
      return Row(
        children: [
          Expanded(child: search),
          for (final f in filters) ...[const SizedBox(width: 12), f],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: filters),
      ],
    );
  }

  // ------------------------------- header ----------------------------------

  Widget _pageTitle() {
    return Row(
      children: [
        if (widget.onMenu != null) ...[
          IconButton(
            tooltip: 'เมนู',
            onPressed: widget.onMenu,
            icon: const Icon(Icons.menu_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 4),
        ],
        const Icon(Icons.group_rounded, size: 48, color: AppColors.blue),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'จัดการผู้ใช้งาน',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ดูและจัดการข้อมูลผู้ใช้งานทั้งหมดในระบบ',
                style: TextStyle(color: AppColors.navy, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------- date range --------------------------------

  static String _d(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year + 543}';

  Widget _dateRangeChip() {
    final today = DateUtils.dateOnly(DateTime.now());
    final presets = <(String, DateTimeRange?)>[
      ('ทุกช่วงวันที่', null),
      ('วันนี้', DateTimeRange(start: today, end: today)),
      (
        '7 วันล่าสุด',
        DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        ),
      ),
      (
        '30 วันล่าสุด',
        DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        ),
      ),
      (
        'เดือนนี้',
        DateTimeRange(start: DateTime(today.year, today.month), end: today),
      ),
    ];
    final label = _range == null
        ? 'เลือกช่วงวันที่'
        : _range!.start == _range!.end
        ? _d(_range!.start)
        : '${_d(_range!.start)} – ${_d(_range!.end)}';

    return PopupMenuButton<int>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (i) async {
        if (i < presets.length) {
          setState(() {
            _range = presets[i].$2;
            _page = 0;
          });
          return;
        }
        // กำหนดเอง: เลือกวันเริ่ม แล้วเลือกวันสิ้นสุด
        final first = DateTime(2020);
        final start = await showThaiDatePicker(
          context: context,
          initialDate: _range?.start ?? today,
          firstDate: first,
          lastDate: today,
          title: 'สมัครตั้งแต่วันที่',
        );
        if (start == null || !mounted) return;
        final end = await showThaiDatePicker(
          context: context,
          initialDate: _range?.end ?? today,
          firstDate: start,
          lastDate: today,
          title: 'ถึงวันที่',
        );
        if (end == null || !mounted) return;
        setState(() {
          _range = DateTimeRange(start: start, end: end);
          _page = 0;
        });
      },
      itemBuilder: (_) => [
        for (var i = 0; i < presets.length; i++)
          PopupMenuItem<int>(value: i, child: Text(presets[i].$1)),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: presets.length,
          child: const Row(
            children: [
              Icon(
                Icons.edit_calendar_outlined,
                size: 18,
                color: AppColors.blue,
              ),
              SizedBox(width: 8),
              Text('กำหนดช่วงวันที่เอง...'),
            ],
          ),
        ),
      ],
      child: _chipBox(
        icon: Icons.calendar_month_outlined,
        label: label,
        muted: _range == null,
      ),
    );
  }

  /// กล่องปุ่มกรองแบบในภาพ (ขาว ขอบฟ้าอ่อน ลูกศรลง)
  Widget _chipBox({required String label, IconData? icon, bool muted = false}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE5F3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.navy),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              color: muted ? AppColors.hint : AppColors.navy,
              fontSize: 15,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.navy),
        ],
      ),
    );
  }

  Widget _menuChip({
    required String? value,
    required String allLabel,
    required List<String> options,
    required ValueChanged<String?> onSelected,
  }) {
    final items = <(String?, String)>[
      (null, allLabel),
      for (final o in options) (o, o),
    ];
    return PopupMenuButton<String?>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (v, text) in items)
          PopupMenuItem<String?>(
            value: v,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: v == value
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.blue,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(text),
              ],
            ),
          ),
      ],
      child: _chipBox(label: value ?? allLabel),
    );
  }

  // -------------------------------- table ----------------------------------

  Widget _table(List<AdminUser> items, {required int offset}) {
    return LayoutBuilder(
      builder: (context, c) {
        // จอแคบ: ซ่อนคอลัมน์อีเมล/เบอร์ แล้วแสดงใต้ชื่อแทน
        final compact = c.maxWidth < 1000;
        const headStyle = TextStyle(
          color: AppColors.navy,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        );
        const cellStyle = TextStyle(color: AppColors.navy, fontSize: 15);

        Widget row({
          required Widget no,
          required Widget name,
          Widget? email,
          Widget? phone,
          required Widget role,
          required Widget status,
          required Widget date,
          required Widget actions,
          double height = 72,
          Color? color,
        }) {
          return Container(
            height: height,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(width: 60, child: no),
                Expanded(flex: 3, child: name),
                if (!compact) ...[
                  Expanded(flex: 3, child: email!),
                  SizedBox(width: 140, child: phone),
                ],
                SizedBox(width: 150, child: role),
                SizedBox(width: 140, child: status),
                SizedBox(width: 110, child: date),
                SizedBox(width: 100, child: actions),
              ],
            ),
          );
        }

        final header = row(
          height: 56,
          color: const Color(0xFFEEF3FB),
          no: const Center(child: Text('ลำดับ', style: headStyle)),
          name: const Text('ชื่อ-สกุล', style: headStyle),
          email: const Text('อีเมล', style: headStyle),
          phone: const Text('เบอร์โทรศัพท์', style: headStyle),
          role: const Center(child: Text('ประเภทผู้ใช้', style: headStyle)),
          status: const Center(child: Text('สถานะ', style: headStyle)),
          date: const Text('สมัครเมื่อ', style: headStyle),
          actions: const Center(child: Text('จัดการ', style: headStyle)),
        );

        final head = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: header,
        );

        if (items.isEmpty) {
          final none = _store.users.isEmpty;
          return Column(
            children: [
              head,
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Column(
                  children: [
                    Icon(
                      none ? Icons.group_outlined : Icons.search_off_rounded,
                      size: 52,
                      color: const Color(0xFFB7CBEE),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      none
                          ? 'ยังไม่มีผู้ใช้งาน'
                          : 'ไม่พบผู้ใช้ที่ตรงกับการค้นหา',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            head,
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFE8EEF8)),
              _HoverRow(
                builder: (hover) {
                  final u = items[i];
                  return row(
                    color: hover ? const Color(0xFFF6F9FF) : null,
                    no: Center(
                      child: Text(
                        '${offset + i + 1}',
                        style: cellStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    name: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cellStyle,
                        ),
                        if (compact)
                          Text(
                            '${u.email} · ${u.phone}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.hint,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    email: Text(
                      u.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cellStyle,
                    ),
                    phone: Text(u.phone, style: cellStyle),
                    role: Center(child: RoleChip(u.role)),
                    status: Center(child: UserStatusChip(u.status)),
                    date: Text(
                      _dateTime(u.createdAt),
                      style: cellStyle.copyWith(fontSize: 14, height: 1.35),
                    ),
                    actions: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () => _openForm(u),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.blue,
                          ),
                        ),
                        IconButton(
                          tooltip: 'ลบ',
                          onPressed: () => _confirmDelete(u),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: _red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 12/10/2568 (ขึ้นบรรทัดใหม่) 14:32 น.
  static String _dateTime(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year + 543}\n'
      '${_two(d.hour)}:${_two(d.minute)} น.';

  // ------------------------------- footer ----------------------------------

  Widget _footer(int pages, int total) {
    Widget box(Widget child, {VoidCallback? onTap, bool active = false}) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: active ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? AppColors.blue : AppColors.border,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    final first = (_page - 2).clamp(0, (pages - 5).clamp(0, pages));
    final last = (first + 5).clamp(0, pages);
    final from = total == 0 ? 0 : _page * _perPage + 1;
    final to = ((_page + 1) * _perPage).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pages > 1
                  ? 'แสดง $from–$to จากทั้งหมด $total รายการ'
                  : 'แสดงทั้งหมด $total รายการ',
              style: const TextStyle(color: AppColors.navy, fontSize: 14),
            ),
          ),
          box(
            Icon(
              Icons.chevron_left_rounded,
              color: _page > 0 ? AppColors.navy : AppColors.border,
            ),
            onTap: _page > 0 ? () => setState(() => _page--) : null,
          ),
          for (var i = first; i < last; i++)
            box(
              Text(
                '${i + 1}',
                style: TextStyle(
                  color: i == _page ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              active: i == _page,
              onTap: () => setState(() => _page = i),
            ),
          box(
            Icon(
              Icons.chevron_right_rounded,
              color: _page < pages - 1 ? AppColors.navy : AppColors.border,
            ),
            onTap: _page < pages - 1 ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.builder});
  final Widget Function(bool hover) builder;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.builder(_hover),
    );
  }
}

/// ป้ายประเภทผู้ใช้ (ผู้ใช้ทั่วไป = ฟ้า, ผู้ดูแลระบบ = ม่วง)
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});
  final String role;

  @override
  Widget build(BuildContext context) {
    final admin = role == 'ผู้ดูแลระบบ';
    final bg = admin ? const Color(0xFFEDE5FD) : const Color(0xFFE3EEFF);
    final fg = admin ? const Color(0xFF6B3FD1) : AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            admin ? Icons.shield_rounded : Icons.person_rounded,
            size: 17,
            color: fg,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ป้ายสถานะบัญชี (ใช้งาน = เขียว, ระงับใช้งาน = เทา) มีจุดสีด้านหน้า
class UserStatusChip extends StatelessWidget {
  const UserStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'ใช้งาน';
    final bg = active ? const Color(0xFFDDF5E6) : const Color(0xFFE6E9EF);
    final fg = active ? const Color(0xFF1E7A45) : const Color(0xFF4A5468);
    final dot = active ? const Color(0xFF22A45D) : const Color(0xFF6B7385);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ฟอร์มเพิ่ม / แก้ไขผู้ใช้
// ---------------------------------------------------------------------------

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.store, required this.user});
  final UserStore store;
  final AdminUser user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  late String _role = widget.user.role;
  late String _status = widget.user.status;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final result = widget.user.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      role: _role,
      status: _status,
    );
    Navigator.pop(context, result);
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
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

  Widget _choice(
    String label,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final o in options) ButtonSegment(value: o, label: Text(o)),
          ],
          selected: {value},
          onSelectionChanged: (s) => setState(() => onChanged(s.first)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.skyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.manage_accounts_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'แก้ไขผู้ใช้งาน',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: _deco('ชื่อ-สกุล *', Icons.person_outline),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ-สกุล' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _deco('อีเมล *', Icons.mail_outline_rounded),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'กรุณากรอกอีเมล';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                      return 'รูปแบบอีเมลไม่ถูกต้อง';
                    }
                    if (widget.store.emailTaken(t, except: widget.user)) {
                      return 'อีเมลนี้มีผู้ใช้แล้ว';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: _deco('เบอร์โทรศัพท์ *', Icons.phone_outlined),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll('-', '');
                    if (digits.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
                    if (digits.length < 9) return 'เบอร์โทรศัพท์ไม่ครบ';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _choice('ประเภทผู้ใช้', kUserRoles, _role, (v) => _role = v),
                const SizedBox(height: 14),
                _choice('สถานะ', kUserStatuses, _status, (v) => _status = v),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(120, 46),
                      ),
                      child: const Text('บันทึกการแก้ไข'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
