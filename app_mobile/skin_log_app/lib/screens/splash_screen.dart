import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Exibida brevemente na inicialização.
/// Verifica se há sessão ativa — se sim, vai para /home; senão, /login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final token = await ApiService.getAccessToken();
    if (token == null) {
      _go('/login');
      return;
    }

    // Tenta validar o token fazendo uma chamada autenticada.
    // Se falhar, tenta refresh. Se o refresh também falhar, vai para login.
    try {
      await ApiService.getMe();
      _go('/home');
    } catch (_) {
      final refreshed = await ApiService.tryRefresh();
      _go(refreshed ? '/home' : '/login');
    }
  }

  void _go(String route) {
    if (mounted) Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SkinLog',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'diário da sua pele',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}