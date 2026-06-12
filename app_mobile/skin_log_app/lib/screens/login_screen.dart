import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true; // toggle entre login e cadastro
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await ApiService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await ApiService.signup(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro de conexão. Verifique se o backend está rodando.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Wordmark ──────────────────────────────────────────────
                  Text(
                    'SkinLog',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _isLogin ? 'Bem-vindo de volta' : 'Crie sua conta',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Erro ──────────────────────────────────────────────────
                  if (_error != null) ErrorBanner(_error!),

                  // ── Nome (só no cadastro) ─────────────────────────────────
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe seu nome.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── E-mail ────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe o e-mail.';
                      }
                      if (!v.contains('@')) return 'E-mail inválido.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Senha ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a senha.';
                      if (v.length < 6) return 'Mínimo 6 caracteres.';
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Botão principal ───────────────────────────────────────
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _submit,
                          child: Text(_isLogin ? 'Entrar' : 'Cadastrar'),
                        ),

                  const SizedBox(height: AppSpacing.xs),

                  // ── Toggle login/cadastro ─────────────────────────────────
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    }),
                    child: Text(_isLogin
                        ? 'Não tem conta? Cadastre-se'
                        : 'Já tem conta? Faça login'),
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