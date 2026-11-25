import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Top banner: title on the left, faded building photo on the right,
/// notification bell and the admin account menu.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.username,
    required this.onLogout,
    this.onMenu,
    this.notificationCount = 0,
    this.compact = false,
    this.icon,
  });

  /// ไอคอนหน้าหัวข้อ (เช่น รูปเฟืองในหน้าตั้งค่า)
  final IconData? icon;

  /// แบบย่อ: ไม่มีรูปตึก ความสูงพอดีกับหัวข้อ
  final bool compact;

  final String title;
  final String subtitle;
  final String username;
  final VoidCallback onLogout;

  /// Shown as a hamburger button when the sidebar is collapsed into a drawer.
  final VoidCallback? onMenu;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPhoto = !compact && constraints.maxWidth >= 640;
        return SizedBox(
          height: compact ? (subtitle.isEmpty ? 64 : 84) : 150,
          child: Stack(
            children: [
              if (showPhoto)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: constraints.maxWidth * 0.58,
                  // Only the right corners are clipped; the left side fades
                  // out completely (no clip edge there, so no visible seam).
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(18),
                    ),
                    child: const _FadedPhoto(),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onMenu != null) ...[
                    IconButton(
                      onPressed: onMenu,
                      icon: const Icon(
                        Icons.menu_rounded,
                        color: AppColors.navy,
                      ),
                      tooltip: 'เมนู',
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (icon != null) ...[
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 6 : 16),
                      child: Icon(icon, size: 46, color: AppColors.blue),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: compact ? 6 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) const SizedBox(height: 2),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _NotificationBell(count: notificationCount),
                  const SizedBox(width: 10),
                  _AccountChip(username: username, onLogout: onLogout),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// กล่องพื้นหลังของหน้า (ใส่ใน DashboardPage) — รูปตึกใช้หาตำแหน่ง
/// เพื่อวาดสีจางให้ตรงกับไล่สีของพื้นหลังทุกจุด
final pageBackgroundKey = GlobalKey(debugLabel: 'pageBackground');

/// Building photo that fades smoothly into the page on the left and bottom.
///
/// ไม่ใช้ ShaderMask (ขอบ layer ทำให้เห็นเส้นบางบนบางจอ) แต่วาด "สีพื้นหลังของหน้า"
/// ทับรูปแบบไล่ความทึบ โดยใช้ไล่สีเดียวกับพื้นหลังและวางตำแหน่งตรงกัน
/// ขอบซ้าย/ล่างของรูปอยู่ในส่วนที่ทับทึบ 100% จึงไม่เห็นขอบรูปเลย
class _FadedPhoto extends StatefulWidget {
  const _FadedPhoto();

  @override
  State<_FadedPhoto> createState() => _FadedPhotoState();
}

class _FadedPhotoState extends State<_FadedPhoto> {
  final _selfKey = GlobalKey();

  static const _imageLeftInset = 0.06; // สัดส่วนความกว้าง
  static const _imageBottomInset = 14.0; // px

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _selfKey,
      builder: (context, c) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: c.maxWidth * _imageLeftInset,
              top: 0,
              right: 0,
              bottom: _imageBottomInset,
              child: Image.asset(
                'assets/images/login_bg.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0.05, 0.25),
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            ),
            CustomPaint(
              painter: _PageFadePainter(
                selfKey: _selfKey,
                leftSolid: _imageLeftInset + 0.08,
                bottomSolidFrom:
                    (c.maxHeight - _imageBottomInset - 2) / c.maxHeight,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageFadePainter extends CustomPainter {
  _PageFadePainter({
    required this.selfKey,
    required this.leftSolid,
    required this.bottomSolidFrom,
  });

  final GlobalKey selfKey;
  final double leftSolid;
  final double bottomSolidFrom;

  /// ตำแหน่งของพื้นหลังหน้า เทียบกับกล่องนี้
  Rect _pageRect(Size size) {
    final page = pageBackgroundKey.currentContext?.findRenderObject();
    final me = selfKey.currentContext?.findRenderObject();
    if (page is RenderBox && me is RenderBox && page.attached && me.attached) {
      final topLeft = me.globalToLocal(page.localToGlobal(Offset.zero));
      return topLeft & page.size;
    }
    return Offset.zero & size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = AppColors.pageGradient.createShader(_pageRect(size));

    void fade(Gradient alpha) {
      canvas.saveLayer(rect, Paint());
      canvas.drawRect(rect, bg);
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = alpha.createShader(rect),
      );
      canvas.restore();
    }

    // ซ้าย: ทึบ 100% เลยขอบรูปไปก่อน แล้วค่อยจางออก
    fade(
      LinearGradient(
        colors: const [
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x66000000),
          Color(0x00000000),
        ],
        stops: [0, leftSolid, 0.42, 0.66],
      ),
    );
    // ล่าง: จางลงจนทึบ 100% ก่อนถึงขอบล่างของรูป
    fade(
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x00000000),
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
        ],
        stops: [0, 0.55, bottomSolidFrom, 1],
      ),
    );
  }

  @override
  bool shouldRepaint(_PageFadePainter old) => true;
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'การแจ้งเตือน',
        onPressed: () {},
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(
            Icons.notifications_rounded,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.username, required this.onLogout});
  final String username;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'บัญชีผู้ใช้',
      offset: const Offset(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.navy),
              SizedBox(width: 10),
              Text('ออกจากระบบ'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navy,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                const Text(
                  'A2 Property',
                  style: TextStyle(
                    color: AppColors.hint,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );
  }
}
