import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/dashboard_page.dart';
void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: GoogleFonts.prompt().fontFamily),
    home: const DashboardPage(username: '11')));
