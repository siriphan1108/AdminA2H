import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/like_stats.dart';
import '../services/project_store.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/panel.dart';
import '../widgets/usage_line_chart.dart';

/// หน้ารายงานและสถิติ: ภาพรวม / ยอดเข้าชม / ความสนใจ
class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.username,
    required this.onLogout,
    this.onMenu,
  });

  final String username;
  final VoidCallback onLogout;
  final VoidCallback? onMenu;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _Tab {
  overview('ภาพรวม'),
  visits('ยอดเข้าชม'),
  interest('ความสนใจ');

  const _Tab(this.label);
  final String label;
}

const _periods = ['เดือนนี้', '7 วันล่าสุด', '30 วันล่าสุด', 'ปีนี้'];

// TODO: ยอดเข้าชมจริงต้องมาจาก backend (ตอนนี้ยังไม่มี จึงว่างไว้)
// ใส่ป้ายแกน X หนึ่งอันต่อหนึ่งค่า แล้วกราฟจะวาดให้เอง
const _visitLabels = <String>[];
const _visitValues = <double>[];

/// สีของแต่ละประเภททรัพย์ (เรียงตาม kProjectTypes)
const _typeColors = [
  Color(0xFF1E6FE8), // คอนโด
  Color(0xFF5B9BD5), // บ้านเดี่ยว
  Color(0xFF7FB8B0), // ทาวน์โฮม
  Color(0xFF0B2563), // ทาวน์เฮาส์
  Color(0xFF9DBDF2), // โฮมออฟฟิศ
  Color(0xFF8E7CC3), // พูลวิลล่า
];

class _ReportsPageState extends State<ReportsPage> {
  final _store = ProjectStore.instance;
  _Tab _tab = _Tab.overview;
  String _period = _periods.first; // ที่เลือกในกล่อง
  String _shownPeriod = _periods.first; // ที่กด "ดูรายงาน" แล้ว

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        DashboardHeader(
          title: 'รายงานและสถิติ',
          subtitle: '',
          compact: true,
          username: widget.username,
          onMenu: widget.onMenu,
          onLogout: widget.onLogout,
          notificationCount: 3,
        ),
        const SizedBox(height: 16),
        _tabs(),
        const SizedBox(height: 20),
        _filterBar(),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: Listenable.merge([_store, LikeStats.instance]),
          builder: (context, _) => switch (_tab) {
            _Tab.overview => _overview(),
            _Tab.visits => _VisitsCard(period: _shownPeriod, chartHeight: 340),
            _Tab.interest => _InterestView(projects: _store.projects),
          },
        ),
      ],
    );
  }

  Widget _overview() {
    return LayoutBuilder(
      builder: (context, c) {
        final visits = _VisitsCard(period: _shownPeriod);
        final types = _TypesCard(projects: _store.projects);
        if (c.maxWidth < 1000) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [visits, const SizedBox(height: 20), types],
          );
        }
        return SizedBox(
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: visits),
              const SizedBox(width: 20),
              Expanded(child: types),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------- tabs ----------------------------------

  Widget _tabs() {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final t in _Tab.values)
          _TabButton(
            label: t.label,
            selected: t == _tab,
            onTap: () => setState(() => _tab = t),
          ),
      ],
    );
  }

  // ------------------------------ filter bar -------------------------------

  Widget _filterBar() {
    final dropdown = PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => setState(() => _period = v),
      itemBuilder: (_) => [
        for (final p in _periods)
          PopupMenuItem(
            value: p,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: p == _period
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.blue,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(p),
              ],
            ),
          ),
      ],
      child: Container(
        height: 52,
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _period,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        dropdown,
        const Spacer(),
        FilledButton(
          onPressed: () => setState(() => _shownPeriod = _period),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blue,
            minimumSize: const Size(140, 52),
            padding: const EdgeInsets.symmetric(horizontal: 26),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('ดูรายงาน'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFE4EDFB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 150),
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              top: BorderSide(
                color: selected ? AppColors.blue : Colors.transparent,
                width: 2.5,
              ),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.blue : AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _comma(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// การ์ดยอดเข้าชมเว็บไซต์
class _VisitsCard extends StatelessWidget {
  const _VisitsCard({required this.period, this.chartHeight = 230});

  final String period;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final total = _visitValues.fold<double>(0, (a, b) => a + b);
    return Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'ยอดเข้าชมเว็บไซต์',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                period,
                style: const TextStyle(color: AppColors.hint, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _comma(total),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: '  ครั้ง',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: const TextStyle(color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          UsageLineChart(
            xLabels: _visitLabels,
            height: chartHeight,
            maxY: math.max(
              1000,
              (total == 0 ? 0 : _visitValues.reduce(math.max)) * 1.2,
            ),
            stepY: 500,
            series: const [
              ChartSeries(
                label: 'การเข้าชม',
                values: _visitValues,
                color: AppColors.blue,
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// การ์ดประเภททรัพย์ยอดนิยม — นับจากโครงการที่กรอกไว้ในระบบ
/// (ประเภทตรงกับตัวเลือกในฟอร์มเพิ่มโครงการ)
class _TypesCard extends StatelessWidget {
  const _TypesCard({
    required this.projects,
    this.detailed = false,
    this.title = 'ประเภททรัพย์ยอดนิยม',
    this.unit = 'โครงการ',
    this.weight,
    this.emptyText = 'ยังไม่มีโครงการ — เพิ่มโครงการแล้วสัดส่วนจะแสดงที่นี่',
  });

  final List<NewProject> projects;

  /// แสดงจำนวนและแถบเปรียบเทียบด้วย
  final bool detailed;
  final String title;
  final String unit;

  /// ค่าที่นับต่อโครงการ (ค่าเริ่มต้น = 1 คือนับจำนวนโครงการ)
  final int Function(NewProject p)? weight;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{for (final t in kProjectTypes) t: 0};
    for (final p in projects) {
      if (counts.containsKey(p.type)) {
        counts[p.type] = counts[p.type]! + (weight?.call(p) ?? 1);
      }
    }
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final rows = [
      for (var i = 0; i < kProjectTypes.length; i++)
        (kProjectTypes[i], counts[kProjectTypes[i]]!, _typeColors[i]),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    String pct(int n) => total == 0 ? '0%' : '${(n * 100 / total).round()}%';

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (type, n, color) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (detailed) ...[
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : n / total,
                        minHeight: 10,
                        color: color,
                        backgroundColor: const Color(0xFFEEF3FB),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      '${_comma(n)} $unit',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.hint),
                    ),
                  ),
                ],
                SizedBox(
                  width: 56,
                  child: Text(
                    pct(n),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.navy, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final donut = SizedBox(
      width: 190,
      height: 190,
      child: CustomPaint(
        painter: _DonutPainter([for (final r in rows) (r.$2, r.$3)]),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _comma(total),
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(unit, style: TextStyle(color: AppColors.hint, fontSize: 13)),
            ],
          ),
        ),
      ),
    );

    return Panel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF9DBDF2), width: 2.5),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 380) {
                return Column(
                  children: [donut, const SizedBox(height: 16), legend],
                );
              }
              return Row(
                children: [
                  donut,
                  const SizedBox(width: 32),
                  Expanded(child: legend),
                ],
              );
            },
          ),
          if (total == 0) ...[
            const SizedBox(height: 10),
            Text(
              emptyText,
              style: const TextStyle(color: AppColors.hint, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// แท็บ "ความสนใจ" = ยอดกดใจ (❤) จากแอป HomeConnect
class _InterestView extends StatelessWidget {
  const _InterestView({required this.projects});
  final List<NewProject> projects;

  @override
  Widget build(BuildContext context) {
    final likes = LikeStats.instance;
    final total = projects.fold<int>(0, (a, p) => a + likes.likesOf(p));
    final ranked = [...projects]
      ..sort((a, b) => likes.likesOf(b).compareTo(likes.likesOf(a)));

    const head = TextStyle(
      color: AppColors.navy,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!likes.hasData)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD9A8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFFB86E00)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ความสนใจนับจากการกดใจ ❤ ในแอป HomeConnect — '
                    'ตอนนี้แอปยังเก็บการกดใจไว้ในเครื่องผู้ใช้ จะแสดงยอดจริงเมื่อเชื่อมเซิร์ฟเวอร์แล้ว',
                    style: TextStyle(color: Color(0xFF8A5300), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        _TypesCard(
          projects: projects,
          detailed: true,
          title: 'ประเภทที่ถูกกดใจมากที่สุด',
          unit: 'ครั้ง',
          weight: likes.likesOf,
          emptyText: 'ยังไม่มีการกดใจ',
        ),
        const SizedBox(height: 20),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE53935),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'โครงการที่ถูกกดใจมากที่สุด',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'รวม ${_comma(total)} ครั้ง',
                      style: const TextStyle(color: AppColors.hint),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFFEEF3FB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 60, child: Text('อันดับ', style: head)),
                    Expanded(flex: 3, child: Text('ชื่อโครงการ', style: head)),
                    Expanded(flex: 2, child: Text('ประเภท', style: head)),
                    SizedBox(
                      width: 120,
                      child: Text(
                        'กดใจ',
                        style: head,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              if (ranked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'ยังไม่มีโครงการ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.hint, fontSize: 15),
                  ),
                ),
              for (var i = 0; i < ranked.length && i < 10; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFE8EEF8)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          ranked[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          ranked[i].type,
                          style: const TextStyle(color: AppColors.hint),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 18,
                              color: Color(0xFFE53935),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _comma(likes.likesOf(ranked[i])),
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices);

  /// (จำนวน, สี)
  final List<(int, Color)> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 38.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final total = slices.fold<int>(0, (a, s) => a + s.$1);
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = const Color(0xFFE4EDFB),
      );
      return;
    }
    var start = -math.pi / 2;
    for (final (n, color) in slices) {
      if (n == 0) continue;
      final sweep = math.pi * 2 * n / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
