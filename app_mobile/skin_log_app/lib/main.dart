import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/analysis_screen.dart';

void main() {
  runApp(const SkinLogApp());
}

class SkinLogApp extends StatelessWidget {
  const SkinLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkinLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/camera': (_) => const CameraScreen(),
        '/analysis': (_) => const AnalysisScreen(),
      },
    );
  }
}