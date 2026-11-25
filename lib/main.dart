import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/dashboard_page.dart';
import 'pages/login_page.dart';
import 'services/admin_auth.dart';
import 'services/project_store.dart';
import 'services/supabase_backend.dart';
import 'services/supabase_projects.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  AdminAuth.instance.useBackend(SupabaseAuthBackend());
  ProjectStore.instance.useBackend(SupabaseProjectBackend());
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2 Property · Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        // Prompt supports both Thai and Latin glyphs. Using the family name
        // (not promptTextTheme) because google_fonts 9 targets material_ui.
        fontFamily: GoogleFonts.prompt().fontFamily,
      ),
      home: const _AuthGate(),
    );
  }
}

/// เปิดเว็บ: ถ้าจดจำการเข้าสู่ระบบไว้ ไปหน้าหลักเลย ไม่งั้นไปหน้าล็อกอิน
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: AdminAuth.instance.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return AdminAuth.instance.current != null
            ? const DashboardPage()
            : const LoginPage();
      },
    );
  }
}
