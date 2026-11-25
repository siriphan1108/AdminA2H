import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/project_store.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/panel.dart';
import '../widgets/thai_date_picker.dart' show kThaiMonths;

/// หน้าจัดการโครงการ: ตารางโครงการทั้งหมด ค้นหา กรองสถานะ เรียงลำดับ
/// ดูรายละเอียด แก้ไข และลบ
class ManageProjectsPage extends StatefulWidget {
  const ManageProjectsPage({
    super.key,
    required this.username,
    required this.onLogout,
    required this.onAdd,
    required this.onEdit,
    this.onMenu,
  });

  final String username;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;
  final VoidCallback onAdd;
  final ValueChanged<NewProject> onEdit;

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

enum _Sort {
  newest('เรียงตามล่าสุด'),
  oldest('เรียงตามเก่าสุด'),
  name('ชื่อ ก-ฮ / A-Z'),
  priceLow('ราคาต่ำ → สูง'),
  priceHigh('ราคาสูง → ต่ำ');

  const _Sort(this.label);
  final String label;
}

class _ManageProjectsPageState extends State<ManageProjectsPage> {
  static const _perPage = 8;

  final _store = ProjectStore.instance;
  final _searchCtrl = TextEditingController();
  String? _status; // null = ทุกสถานะ
  _Sort _sort = _Sort.newest;
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

  List<NewProject> _visible() {
    final q = _searchCtrl.text.trim().toLowerCase();
    // store เรียงใหม่ → เก่าอยู่แล้ว
    final list = _store.projects.where((p) {
      if (_status != null && p.status != _status) return false;
      if (q.isEmpty) return true;
      return [
        p.name,
        p.developer,
        p.province,
        p.district,
        p.subDistrict,
        p.type,
      ].any((t) => t.toLowerCase().contains(q));
    }).toList();
    switch (_sort) {
      case _Sort.newest:
        break;
      case _Sort.oldest:
        list.setAll(0, list.reversed.toList());
      case _Sort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _Sort.priceLow:
        list.sort((a, b) => a.startPrice.compareTo(b.startPrice));
      case _Sort.priceHigh:
        list.sort((a, b) => b.startPrice.compareTo(a.startPrice));
    }
    return list;
  }

  Future<void> _confirmDelete(NewProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบโครงการ?'),
        content: Text('ต้องการลบ "${p.name}" ใช่ไหม ลบแล้วกู้คืนไม่ได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบโครงการ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final warning = await _store.remove(p);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(warning ?? 'ลบ "${p.name}" แล้ว'),
          behavior: SnackBarBehavior.floating,
          width: 460,
          backgroundColor: AppColors.navy,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardHeader(
            title: 'จัดการโครงการ',
            subtitle: 'หน้าหลัก  ›  จัดการโครงการ',
            username: widget.username,
            onMenu: widget.onMenu,
            onLogout: widget.onLogout,
            notificationCount: 3,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final all = _visible();
                final pages = (all.length / _perPage).ceil().clamp(1, 9999);
                if (_page >= pages) _page = pages - 1;
                final pageItems = all
                    .skip(_page * _perPage)
                    .take(_perPage)
                    .toList();
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _toolbar(),
                      if (_store.loadError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                color: Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _store.loadError!,
                                  style: const TextStyle(
                                    color: Color(0xFFB71C1C),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _store.reload,
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Panel(
                        padding: EdgeInsets.zero,
                        child: _table(pageItems, total: all.length),
                      ),
                      if (all.length > _perPage) ...[
                        const SizedBox(height: 16),
                        _pagination(pages, all.length),
                      ],
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
      borderSide: const BorderSide(color: Colors.white),
    );
    final search = TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() => _page = 0),
      decoration: InputDecoration(
        hintText: 'ค้นหาโครงการ...',
        hintStyle: const TextStyle(color: AppColors.hint),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
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

    final addBtn = FilledButton.icon(
      onPressed: widget.onAdd,
      icon: const Icon(Icons.add_rounded),
      label: const Text('เพิ่มโครงการใหม่'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    final filters = [
      _menuChip<String?>(
        value: _status,
        label: _status ?? 'สถานะทั้งหมด',
        items: [
          (null, 'สถานะทั้งหมด'),
          for (final s in kProjectStatuses) (s, s),
        ],
        onSelected: (v) => setState(() {
          _status = v;
          _page = 0;
        }),
      ),
      _menuChip<_Sort>(
        value: _sort,
        label: _sort.label,
        items: [for (final s in _Sort.values) (s, s.label)],
        onSelected: (v) => setState(() => _sort = v),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            children: [
              SizedBox(width: 300, child: search),
              const SizedBox(width: 12),
              ...filters.expand((f) => [f, const SizedBox(width: 12)]),
              const Spacer(),
              addBtn,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                addBtn,
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: filters),
          ],
        );
      },
    );
  }

  /// ปุ่มเมนูแบบในภาพ (สีขาว มุมมน ลูกศรลง)
  Widget _menuChip<T>({
    required T value,
    required String label,
    required List<(T, String)> items,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (v, text) in items)
          PopupMenuItem<T>(
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
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------- table ----------------------------------

  Widget _table(List<NewProject> items, {required int total}) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 760;
        const headStyle = TextStyle(
          color: AppColors.navy,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        );

        Widget row({
          required Widget image,
          required Widget name,
          Widget? location,
          required Widget status,
          required Widget actions,
          double height = 72,
          Color? color,
        }) {
          return Container(
            height: height,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: compact ? 72 : 110, child: image),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: name),
                if (!compact) Expanded(flex: 3, child: location!),
                SizedBox(width: compact ? 120 : 170, child: status),
                SizedBox(width: compact ? 120 : 150, child: actions),
              ],
            ),
          );
        }

        final header = row(
          height: 56,
          color: const Color(0xFFEEF3FB),
          image: const Center(child: Text('รูปภาพ', style: headStyle)),
          name: const Text('ชื่อโครงการ', style: headStyle),
          location: const Text('ทำเลที่ตั้ง', style: headStyle),
          status: const Center(child: Text('สถานะ', style: headStyle)),
          actions: const Center(child: Text('จัดการ', style: headStyle)),
        );

        if (items.isEmpty) {
          final noProjects = _store.projects.isEmpty;
          return Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: header,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 56),
                child: Column(
                  children: [
                    Icon(
                      noProjects
                          ? Icons.apartment_rounded
                          : Icons.search_off_rounded,
                      size: 52,
                      color: const Color(0xFFB7CBEE),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      noProjects
                          ? 'ยังไม่มีโครงการ'
                          : 'ไม่พบโครงการที่ตรงกับการค้นหา',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (noProjects) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: widget.onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('เพิ่มโครงการแรก'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: header,
            ),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFE8EEF8)),
              _ProjectRow(
                builder: (hover) {
                  final p = items[i];
                  return row(
                    color: hover ? const Color(0xFFF6F9FF) : null,
                    image: Center(child: _Thumb(project: p)),
                    name: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          compact ? _location(p) : p.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.hint,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    location: Text(
                      _location(p),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                      ),
                    ),
                    status: Center(child: StatusChip(p.status)),
                    actions: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _iconAction(
                          Icons.visibility_outlined,
                          'ดูรายละเอียด',
                          AppColors.blue,
                          () => showProjectDetails(
                            context,
                            p,
                            onEdit: () => widget.onEdit(p),
                          ),
                        ),
                        _iconAction(
                          Icons.edit_outlined,
                          'แก้ไข',
                          AppColors.blue,
                          () => widget.onEdit(p),
                        ),
                        _iconAction(
                          Icons.delete_outline_rounded,
                          'ลบ',
                          const Color(0xFFE53935),
                          () => _confirmDelete(p),
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

  String _location(NewProject p) {
    final province = p.province == 'กรุงเทพมหานคร' ? 'กรุงเทพฯ' : p.province;
    return [p.district, province].where((e) => e.isNotEmpty).join(', ');
  }

  Widget _iconAction(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color),
      splashRadius: 22,
    );
  }

  // ------------------------------ pagination -------------------------------

  Widget _pagination(int pages, int total) {
    final from = _page * _perPage + 1;
    final to = ((_page + 1) * _perPage).clamp(0, total);

    Widget box(Widget child, {VoidCallback? onTap, bool active = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    // แสดงไม่เกิน 5 เลขหน้า รอบ ๆ หน้าปัจจุบัน
    final start = (_page - 2).clamp(0, (pages - 5).clamp(0, pages));
    final end = (start + 5).clamp(0, pages);

    return Row(
      children: [
        Text(
          'แสดง $from–$to จาก $total โครงการ',
          style: const TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const Spacer(),
        box(
          const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
          onTap: _page > 0 ? () => setState(() => _page--) : null,
        ),
        for (var i = start; i < end; i++)
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
          onTap: _page < pages - 1 ? () => setState(() => _page++) : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// แถวที่เปลี่ยนสีพื้นเมื่อเอาเมาส์ชี้
class _ProjectRow extends StatefulWidget {
  const _ProjectRow({required this.builder});
  final Widget Function(bool hover) builder;

  @override
  State<_ProjectRow> createState() => _ProjectRowState();
}

class _ProjectRowState extends State<_ProjectRow> {
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.project});

  final NewProject project;
  static const width = 80.0;
  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: project.imageBytes.isEmpty
            ? const ColoredBox(
                color: AppColors.skyLight,
                child: Icon(Icons.image_outlined, color: AppColors.hint),
              )
            : Image.memory(
                project.imageBytes.first,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}

/// ป้ายสถานะโครงการ (สีตามสถานะ)
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  static (Color bg, Color fg) colorsOf(String s) => switch (s) {
    'เปิดขาย' => (const Color(0xFFDDF5E6), const Color(0xFF1E8E4E)),
    'กำลังก่อสร้าง' => (const Color(0xFFFFF0DA), const Color(0xFFB86E00)),
    'เตรียมเปิดตัว' => (const Color(0xFFEEE7FD), const Color(0xFF6B46C1)),
    'สร้างเสร็จพร้อมอยู่' => (const Color(0xFFDDF3F3), const Color(0xFF0F7C7C)),
    _ => (const Color(0xFFE3ECFA), const Color(0xFF3B5B9A)), // ปิดการขาย
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// รายละเอียดโครงการ (ปุ่มรูปตา)
// ---------------------------------------------------------------------------

Future<void> showProjectDetails(
  BuildContext context,
  NewProject p, {
  VoidCallback? onEdit,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ProjectDetailsDialog(
      project: p,
      onEdit: onEdit == null
          ? null
          : () {
              Navigator.pop(ctx);
              onEdit();
            },
    ),
  );
}

class _ProjectDetailsDialog extends StatefulWidget {
  const _ProjectDetailsDialog({required this.project, this.onEdit});
  final NewProject project;
  final VoidCallback? onEdit;

  @override
  State<_ProjectDetailsDialog> createState() => _ProjectDetailsDialogState();
}

class _ProjectDetailsDialogState extends State<_ProjectDetailsDialog> {
  int _image = 0;

  String _money(double? v) => v == null
      ? '-'
      : '${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} บาท';

  String _date(DateTime? d) =>
      d == null ? '-' : '${d.day} ${kThaiMonths[d.month - 1]} ${d.year + 543}';

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final price = p.maxPrice == null
        ? _money(p.startPrice)
        : '${_money(p.startPrice).replaceAll(' บาท', '')} – ${_money(p.maxPrice)}';
    final location = [
      p.address,
      p.subDistrict,
      p.district,
      p.province,
    ].where((e) => e.isNotEmpty).join(' ');

    final info = <(String, String)>[
      ('ประเภท', p.type),
      ('บริษัทผู้พัฒนา', p.developer),
      ('ราคา', price),
      ('เงินดาวน์', '${p.downPaymentPercent}%'),
      ('เงินจอง', _money(p.reservationFee)),
      ('ราคาหน้าสัญญา', _money(p.contractPrice)),
      (
        'ค่าคอมมิชชั่น',
        '${p.commissionPercent % 1 == 0 ? p.commissionPercent.toInt() : p.commissionPercent}%'
            '${p.commissionAmount == null ? '' : ' (${_money(p.commissionAmount)})'}',
      ),
      ('วันที่เริ่มขาย', _date(p.saleStart)),
      ('วันสิ้นสุดโปรโมชั่น', _date(p.promoEnd)),
      ('จำนวนยูนิต', p.units.isEmpty ? '-' : '${p.units.length} ยูนิต'),
      (
        'ผู้ติดต่อ',
        [
          p.contactName,
          p.contactPhone,
          p.contactEmail,
        ].where((e) => e.isNotEmpty).join(' · '),
      ),
    ];

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p.imageBytes.isNotEmpty) _gallery(p),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              StatusChip(p.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: AppColors.hint,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    color: AppColors.hint,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 24,
                            runSpacing: 14,
                            children: [
                              for (final (k, v) in info)
                                SizedBox(
                                  width: 230,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        k,
                                        style: const TextStyle(
                                          color: AppColors.hint,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        v.isEmpty ? '-' : v,
                                        style: const TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (p.facilities.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'สิ่งอำนวยความสะดวก',
                              style: TextStyle(
                                color: AppColors.hint,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final f in p.facilities)
                                  Chip(
                                    label: Text(f),
                                    backgroundColor: AppColors.skyLight,
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                          if (p.priceNote.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'โปรโมชั่น / หมายเหตุ',
                              style: TextStyle(
                                color: AppColors.hint,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              p.priceNote,
                              style: const TextStyle(color: AppColors.navy),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
                    child: const Text('ปิด'),
                  ),
                  if (widget.onEdit != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('แก้ไขโครงการ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 44),
                      ),
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

  Widget _gallery(NewProject p) {
    final images = p.imageBytes;
    final i = _image.clamp(0, images.length - 1);
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Image.memory(
            images[i],
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
          ),
        ),
        if (images.length > 1)
          Container(
            height: 76,
            color: const Color(0xFFF3F7FE),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, k) => GestureDetector(
                onTap: () => setState(() => _image = k),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: k == i ? AppColors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      images[k],
                      width: 80,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
