import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const McsApp());
}

class McsApp extends StatelessWidget {
  const McsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MCS Hitachi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(),
    );
  }
}
