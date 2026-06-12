import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  Map<String, String> _user = {};
  Map<String, dynamic> _latest = {};
  Map<String, dynamic> _streak = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getSavedUser(),
        ApiService.getLatestRecord(),
        ApiService.getStreak(),
      ]);
      setState(() {
        _user = results[0] as Map<String, String>;
        _latest = results[1];
        _streak = results[2];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar dados.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  bool get _registeredToday {
    if (_latest.isEmpty) return false;
    final createdAt = DateTime.tryParse(_latest['created_at'] ?? '');
    if (createdAt == null) return false;
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SkinLog'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error != null) ErrorBanner(_error!),

                  // ── Saudação ─────────────────────────────────────────────
                  Text('Olá, ${_user['name'] ?? 'usuário'}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_user['email'] ?? '',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Status + streak (lado a lado) ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatusTile(registeredToday: _registeredToday),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StreakTile(
                          days: (_streak['streak_days'] ?? 0) as int,
                        ),
                      ),
                    ],
                  ),

                  const Divider(),

                  // ── Último registro ───────────────────────────────────────
                  Text('Último registro',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.md),
                  if (_latest.isEmpty)
                    Text('Nenhum registro ainda.',
                        style: TextStyle(color: AppColors.muted))
                  else
                    _LatestRecordCard(record: _latest),

                  const SizedBox(height: AppSpacing.lg),

                  // ── CTA: Registrar hoje ───────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/camera');
                      _loadData();
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Registrar hoje'),
                  ),

                  const SizedBox(height: AppSpacing.sm + 4),

                  // ── CTA: Ver análises ─────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/analysis');
                      _loadData();
                    },
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('Ver análises'),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Tile de status do dia ────────────────────────────────────────────────────

class _StatusTile extends StatelessWidget {
  final bool registeredToday;
  const _StatusTile({required this.registeredToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            registeredToday ? Icons.check_circle : Icons.circle_outlined,
            size: 22,
            color: AppColors.ink,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            registeredToday ? 'Registro feito' : 'Pendente hoje',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Tile de streak ───────────────────────────────────────────────────────────

class _StreakTile extends StatelessWidget {
  final int days;
  const _StreakTile({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$days',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  )),
          const SizedBox(height: AppSpacing.xs),
          Text(
            days == 1 ? 'dia seguido' : 'dias seguidos',
            style: const TextStyle(color: AppColors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Card do último registro ──────────────────────────────────────────────────

class _LatestRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _LatestRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final createdAt = (record['created_at'] ?? '').toString();
    final date = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    final score = record['ai_score'];
    final notes = record['notes'];
    final signedUrl = record['photo_signed_url'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail arredondada.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: signedUrl.isNotEmpty
                  ? Image.network(
                      signedUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date,
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: AppSpacing.xs),
                  if (score != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$score',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 2),
                        Text('/ 10',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    )
                  else
                    Text('Analisando com IA...',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  if (notes != null && notes.toString().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(notes.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 72,
        height: 72,
        color: AppColors.subtle,
        child: const Icon(Icons.image_outlined, color: AppColors.faint),
      );
}