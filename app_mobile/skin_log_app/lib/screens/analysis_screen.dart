import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _records = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loadingMore = false;

  // ── Modo comparação ──────────────────────────────────────────────────────
  bool _compareMode = false;
  final List<String> _selectedIds = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _records = [];
        _nextCursor = null;
        _hasMore = false;
      });
    }

    try {
      final data = await ApiService.listRecords(
        limit: 20,
        cursor: reset ? null : _nextCursor,
      );
      final items = (data['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _records = reset ? items : [..._records, ...items];
        _nextCursor = data['next_cursor'];
        _hasMore = data['has_more'] ?? false;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar registros.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final data = await ApiService.listRecords(limit: 20, cursor: _nextCursor);
      final items = (data['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _records = [..._records, ...items];
        _nextCursor = data['next_cursor'];
        _hasMore = data['has_more'] ?? false;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // ── Seleção para comparação ───────────────────────────────────────────────

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      }
    });

    if (_selectedIds.length == 2) _goCompare();
  }

  Future<void> _goCompare() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompareScreen(
          recordIdA: _selectedIds[0],
          recordIdB: _selectedIds[1],
        ),
      ),
    );
    setState(() {
      _compareMode = false;
      _selectedIds.clear();
    });
  }

  // ── Detalhe de um registro ────────────────────────────────────────────────

  void _showDetail(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordDetailSheet(
        record: record,
        onDelete: () async {
          Navigator.pop(context);
          await ApiService.deleteRecord(record['id']);
          _loadRecords();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_compareMode ? 'Selecione 2 registros' : 'Análises'),
        actions: [
          if (!_compareMode)
            TextButton(
              onPressed: () => setState(() => _compareMode = true),
              child: const Text('Comparar'),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _compareMode = false;
                _selectedIds.clear();
              }),
              child: const Text('Cancelar'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: _records.isEmpty
                  ? const Center(child: Text('Nenhum registro encontrado.'))
                  : Column(
                      children: [
                        // ── Erro ──────────────────────────────────────────
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                                AppSpacing.md, AppSpacing.md, 0),
                            child: ErrorBanner(_error!),
                          ),

                        // ── Instrução de comparação ───────────────────────
                        if (_compareMode)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm + 2,
                                horizontal: AppSpacing.md),
                            color: AppColors.subtle,
                            child: Text(
                              'Selecionados ${_selectedIds.length}/2 — toque em dois registros',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.muted),
                            ),
                          ),

                        // ── Lista ─────────────────────────────────────────
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 200) {
                                _loadMore();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              itemCount:
                                  _records.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == _records.length) {
                                  return const Center(
                                      child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ));
                                }
                                final record = _records[i];
                                final isSelected =
                                    _selectedIds.contains(record['id']);
                                return _RecordListTile(
                                  record: record,
                                  compareMode: _compareMode,
                                  isSelected: isSelected,
                                  onTap: _compareMode
                                      ? () => _toggleSelect(record['id'])
                                      : () => _showDetail(record),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

// ─── Tile de cada registro ────────────────────────────────────────────────────

class _RecordListTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool compareMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecordListTile({
    required this.record,
    required this.compareMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final score = record['ai_score'];
    final createdAt = record['created_at'] ?? '';
    final signedUrl = record['photo_signed_url'] ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      tileColor: isSelected ? AppColors.subtle : null,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: signedUrl.isNotEmpty
            ? Image.network(signedUrl, width: 52, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbPlaceholder())
            : _thumbPlaceholder(),
      ),
      title: Text(
        createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        score != null ? 'Score $score / 10' : 'Analisando...',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      trailing: compareMode
          ? Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.ink : AppColors.faint,
            )
          : const Icon(Icons.chevron_right, color: AppColors.faint),
      onTap: onTap,
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 52,
        height: 52,
        color: AppColors.subtle,
        child: const Icon(Icons.image_outlined, color: AppColors.faint),
      );
}

// ─── Bottom sheet de detalhe ──────────────────────────────────────────────────

class _RecordDetailSheet extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  const _RecordDetailSheet({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final analysis = record['ai_analysis'] as Map<String, dynamic>?;
    final signedUrl = record['photo_signed_url'] ?? '';
    final score = record['ai_score'];
    final notes = record['notes'];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Registro', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('ID: ${record['id']}',
              style: Theme.of(context).textTheme.bodySmall),
          Text('Data: ${record['created_at']}'),
          const SizedBox(height: 12),

          // Foto
          if (signedUrl.isNotEmpty)
            Image.network(signedUrl, height: 200, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Text('[erro ao carregar imagem]')),

          const SizedBox(height: 12),

          // Score
          Text(
            score != null
                ? 'Score IA: $score / 10'
                : 'Aguardando análise da IA...',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          if (notes != null && notes.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notas: $notes'),
          ],

          // Análise detalhada
          if (analysis != null) ...[
            const Divider(height: 24),
            const Text('Análise detalhada',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _AnalysisRow('Vermelhidão', analysis['redness']),
            _AnalysisRow('Acne', analysis['acne']),
            _AnalysisRow('Ressecamento', analysis['dryness']),
            _AnalysisRow('Oleosidade', analysis['oiliness']),
            _AnalysisRow('Observações', analysis['observations']),
            _AnalysisRow('Recomendações', analysis['recommendations']),
          ],

          const SizedBox(height: 24),

          // Deletar
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirmar exclusão'),
                  content: const Text(
                      'Tem certeza que quer remover este registro? A operação é irreversível.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir')),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
            icon: const Icon(Icons.delete),
            label: const Text('Excluir registro'),
          ),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _AnalysisRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }
}

// ─── Tela de Comparação ───────────────────────────────────────────────────────

class CompareScreen extends StatefulWidget {
  final String recordIdA;
  final String recordIdB;

  const CompareScreen({
    super.key,
    required this.recordIdA,
    required this.recordIdB,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.compareRecords(
        recordIdA: widget.recordIdA,
        recordIdB: widget.recordIdB,
      );
      setState(() => _result = data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao comparar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparação')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ErrorBanner(_error!),
                  ))
              : _buildComparison(),
    );
  }

  Widget _buildComparison() {
    final result = _result!;
    final recA = result['record_a'] as Map<String, dynamic>;
    final recB = result['record_b'] as Map<String, dynamic>;
    final diff = result['score_diff'];
    final days = result['days_between'];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Resumo ─────────────────────────────────────────────────────────
        if (diff != null)
          Row(
            children: [
              Icon(
                diff > 0
                    ? Icons.arrow_upward
                    : diff < 0
                        ? Icons.arrow_downward
                        : Icons.remove,
                size: 26,
                color: AppColors.ink,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                diff == 0
                    ? 'Sem diferença'
                    : '${diff.abs()} ${diff.abs() == 1 ? 'ponto' : 'pontos'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                diff > 0
                    ? 'de melhora'
                    : diff < 0
                        ? 'de piora'
                        : '',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          )
        else
          Text('Score indisponível para um ou ambos os registros.',
              style: TextStyle(color: AppColors.muted)),

        const SizedBox(height: AppSpacing.xs),
        Text('$days dia(s) entre os registros',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),

        const Divider(),

        // ── Comparação lado a lado ─────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CompareCard(label: 'A', record: recA)),
            const SizedBox(width: 12),
            Expanded(child: _CompareCard(label: 'B', record: recB)),
          ],
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String label;
  final Map<String, dynamic> record;

  const _CompareCard({required this.label, required this.record});

  @override
  Widget build(BuildContext context) {
    final score = record['ai_score'];
    final date = (record['created_at'] ?? '').toString();
    final signedUrl = record['photo_signed_url'] ?? '';
    final analysis = record['ai_analysis'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registro $label',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(date.length >= 10 ? date.substring(0, 10) : date,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            if (signedUrl.isNotEmpty)
              Image.network(signedUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Text('[sem imagem]')),
            const SizedBox(height: 6),
            Text(
              score != null ? 'Score: $score/10' : 'Score: -',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (analysis != null) ...[
              Text('Acne: ${analysis['acne'] ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
              Text('Oleosidade: ${analysis['oiliness'] ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
              Text('Vermelhidão: ${analysis['redness'] ?? '-'}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}