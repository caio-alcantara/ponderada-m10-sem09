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

  /// Diálogo escondido (long-press no logo) para configurar a URL do backend.
  Future<void> _openBackendConfig() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _BackendConfigDialog(),
    );
    if (message == null || !mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
                  // ── Wordmark (long-press: configurar backend) ─────────────
                  GestureDetector(
                    onLongPress: _openBackendConfig,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'SkinLog',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
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

/// Diálogo escondido para configurar a URL do backend.
///
/// É um widget próprio para que o [TextEditingController] tenha seu ciclo de
/// vida gerenciado por um State — evitando "used after being disposed" quando o
/// diálogo fecha com animação. Retorna uma mensagem de feedback via `pop`, ou
/// `null` se cancelado.
class _BackendConfigDialog extends StatefulWidget {
  const _BackendConfigDialog();

  @override
  State<_BackendConfigDialog> createState() => _BackendConfigDialogState();
}

class _BackendConfigDialogState extends State<_BackendConfigDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: ApiService.currentOrigin);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      await ApiService.clearBackendOrigin();
    } else {
      await ApiService.setBackendOrigin(value);
    }
    if (mounted) Navigator.pop(context, 'Backend: ${ApiService.currentOrigin}');
  }

  Future<void> _reset() async {
    await ApiService.clearBackendOrigin();
    if (mounted) Navigator.pop(context, 'Backend redefinido para o padrão.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar backend'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'URL onde o backend está rodando. '
              'Ex.: http://192.168.0.10:8000',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'URL do backend',
                hintText: 'http://192.168.0.10:8000',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Padrão: ${ApiService.defaultOrigin}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _reset, child: const Text('Redefinir')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}