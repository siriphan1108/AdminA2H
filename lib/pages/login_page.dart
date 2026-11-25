import 'package:flutter/material.dart';

import '../services/admin_auth.dart';
import '../theme/app_colors.dart';
import '../widgets/a2_logo.dart';
import '../widgets/login_background.dart';
import 'dashboard_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/login_bg.jpg',
                  fit: BoxFit.cover,
                  // Keep the main tower in view on the left half.
                  alignment: wide ? const Alignment(0.3, 0) : Alignment.center,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.primary),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: LoginBackgroundPainter(split: wide),
                ),
              ),
              // ยังไม่มีแอดมินเลย = หน้าสร้างผู้ดูแลหลักคนแรก
              ListenableBuilder(
                listenable: AdminAuth.instance,
                builder: (context, _) {
                  final card = _Scrollable(
                    child: AdminAuth.instance.hasAdmins
                        ? const LoginCard()
                        : const SetupCard(),
                  );
                  if (!wide) return Center(child: card);
                  return Row(
                    children: [
                      const Expanded(child: _HeroPanel()),
                      Expanded(child: Center(child: card)),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: child,
    );
  }
}

/// Left side: brand, title and tagline over the photo.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(-0.45, -0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const A2Logo(color: Colors.white, width: 150),
              const SizedBox(height: 24),
              Container(
                width: 260,
                height: 1,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'HomeConnect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Admin Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              Text.rich(
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 17,
                  height: 1.4,
                ),
                const TextSpan(
                  children: [
                    TextSpan(text: '"Manage Your Properties\nwith '),
                    TextSpan(
                      text: 'HomeConnect',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                    TextSpan(text: '"'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The white login card with the form.
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminAuth.instance.login(
        _usernameCtrl.text,
        _passwordCtrl.text,
        remember: _remember,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
    );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
      prefixIcon: Icon(icon, color: AppColors.navy),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(Colors.red.shade300),
      focusedErrorBorder: border(Colors.red, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: A2Logo(color: AppColors.navy, width: 120)),
              const SizedBox(height: 16),
              const Text(
                'Admin Panel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const _DividerLabel('เข้าสู่ระบบสำหรับผู้ดูแลระบบ'),
              const SizedBox(height: 28),
              TextFormField(
                controller: _usernameCtrl,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: _decoration('ชื่อผู้ใช้หรืออีเมล', Icons.person),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'กรุณากรอกชื่อผู้ใช้'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _decoration(
                  'รหัสผ่าน (Password)',
                  Icons.lock,
                  suffix: IconButton(
                    tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.navy,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null,
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _remember = !_remember),
                child: Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      activeColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.hint, width: 1.4),
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                    const Text(
                      'จดจำการเข้าสู่ระบบ',
                      style: TextStyle(color: AppColors.navy, fontSize: 15),
                    ),
                  ],
                ),
              ),
              if (_error != null) _ErrorBox(_error!),
              const SizedBox(height: 18),
              _GradientButton(loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// สร้างผู้ดูแลหลักคนแรก — แสดงเฉพาะตอนที่ยังไม่มีแอดมินในระบบเลย
class SetupCard extends StatefulWidget {
  const SetupCard({super.key});

  @override
  State<SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<SetupCard> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminAuth.instance.createFirstOwner(
        name: _name.text,
        username: _username.text,
        email: _email.text,
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DashboardPage()),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool password = false,
    String? Function(String?)? validator,
    bool last = false,
  }) {
    OutlineInputBorder border(Color col, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: col, width: w),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: password && _obscure,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: last ? (_) => _submit() : null,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
          prefixIcon: Icon(icon, color: AppColors.navy),
          suffixIcon: password
              ? IconButton(
                  tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.navy,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: border(AppColors.border),
          focusedBorder: border(AppColors.primary, 1.6),
          errorBorder: border(Colors.red.shade300),
          focusedErrorBorder: border(Colors.red, 1.6),
        ),
      ),
    );
  }

  static String? _req(String? v, String msg) =>
      (v ?? '').trim().isEmpty ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(36, 34, 36, 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: A2Logo(color: AppColors.navy, width: 100)),
            const SizedBox(height: 14),
            const Text(
              'ตั้งค่าครั้งแรก',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'สร้างบัญชีผู้ดูแลหลัก เพื่อใช้เข้าสู่ระบบและเพิ่มผู้ดูแลคนอื่น',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.hint, fontSize: 14),
            ),
            const SizedBox(height: 22),
            _field(
              _name,
              'ชื่อที่แสดง',
              Icons.badge_outlined,
              validator: (v) => _req(v, 'กรุณากรอกชื่อ'),
            ),
            _field(
              _username,
              'ชื่อผู้ใช้ (Username)',
              Icons.person,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
                if (!RegExp(r'^[A-Za-z0-9._-]{3,}$').hasMatch(t)) {
                  return 'ใช้ a-z, 0-9, . _ - อย่างน้อย 3 ตัว';
                }
                return null;
              },
            ),
            _field(
              _email,
              'อีเมล',
              Icons.mail_outline_rounded,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'กรุณากรอกอีเมล';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                    ? null
                    : 'รูปแบบอีเมลไม่ถูกต้อง';
              },
            ),
            _field(
              _password,
              'รหัสผ่าน (อย่างน้อย 8 ตัว)',
              Icons.lock,
              password: true,
              validator: AdminAuth.validatePassword,
            ),
            _field(
              _confirm,
              'ยืนยันรหัสผ่าน',
              Icons.lock_outline,
              password: true,
              last: true,
              validator: (v) =>
                  v != _password.text ? 'รหัสผ่านไม่ตรงกัน' : null,
            ),
            if (_error != null) _ErrorBox(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('สร้างบัญชีและเข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.navy.withValues(alpha: 0.35),
      ),
    );
    return Row(
      children: [
        line,
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.navy, fontSize: 15),
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.loading, required this.onPressed});
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, AppColors.primary],
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
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
