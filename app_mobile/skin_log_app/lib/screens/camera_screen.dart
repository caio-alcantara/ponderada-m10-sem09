import 'dart:typed_data';
import 'package:camera/camera.dart'; // também exporta XFile
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/face_oval_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // ── Câmera ao vivo ─────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _cameraReady = false;
  String? _cameraError;

  // ── Fluxo ──────────────────────────────────────────────────────────────────
  // null = fase de captura; preenchido = fase de revisão.
  Uint8List? _photoBytes;
  String _photoName = 'registro.jpg';
  String _photoContentType = 'image/jpeg';
  final _notesController = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'Nenhuma câmera disponível.');
        return;
      }
      // Prefere a câmera frontal.
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      setState(() => _cameraError = 'Não foi possível acessar a câmera.');
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _cameraReady = true;
        _cameraError = null;
      });
    } catch (e) {
      setState(() => _cameraError = 'Permissão de câmera negada.');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _cameraReady = false);
    await _controller?.dispose();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startController(_cameras[_cameraIndex]);
  }

  Future<void> _useXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final contentType = _contentTypeFor(file);
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoContentType = contentType;
      _photoName = 'registro.${contentType.split('/').last}';
      _result = null;
      _error = null;
    });
  }

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final shot = await controller.takePicture();
      await _useXFile(shot);
    } catch (e) {
      setState(() => _error = 'Falha ao capturar a foto.');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) await _useXFile(picked);
  }

  void _retake() {
    setState(() {
      _photoBytes = null;
      _result = null;
      _error = null;
      _notesController.clear();
    });
  }

  Future<void> _submit() async {
    if (_photoBytes == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final record = await ApiService.createRecord(
        bytes: _photoBytes!,
        filename: _photoName,
        contentType: _photoContentType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      setState(() => _result = record);
      await NotificationService.cancelAll();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Erro ao enviar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fase de revisão / envio.
    if (_photoBytes != null) return _buildReview(context);
    // Fase de captura ao vivo.
    return _buildCapture(context);
  }

  // ─── Fase 1: captura ao vivo ───────────────────────────────────────────────

  Widget _buildCapture(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Novo Registro',
            style: TextStyle(color: Colors.white)),
      ),
      body: _cameraError != null
          ? _buildCameraError()
          : !_cameraReady || _controller == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview da câmera preenchendo a tela.
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1080,
                        height: _controller!.value.previewSize?.width ?? 1920,
                        child: CameraPreview(_controller!),
                      ),
                    ),

                    // Guia oval.
                    const Positioned.fill(
                      child: CustomPaint(painter: FaceOvalPainter()),
                    ),

                    // Instrução no topo.
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 72,
                      left: 0,
                      right: 0,
                      child: const Center(
                        child: Text(
                          'Posicione seu rosto no oval',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    if (_error != null)
                      Positioned(
                        bottom: 160,
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        child: ErrorBanner(_error!),
                      ),

                    // Barra inferior de controles.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildControlBar(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Enviar arquivo / galeria.
          _RoundIconButton(
            icon: Icons.upload_file_outlined,
            label: 'Arquivo',
            onTap: _pickFromGallery,
          ),

          // Obturador.
          GestureDetector(
            onTap: _capture,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white24, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('Foto',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),

          // Virar câmera.
          _RoundIconButton(
            icon: Icons.cameraswitch_outlined,
            label: 'Virar',
            onTap: _cameras.length > 1 ? _flipCamera : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Usar galeria'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Fase 2: revisão e envio ───────────────────────────────────────────────

  Widget _buildReview(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Registro'),
        leading: _result == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _retake,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_error != null) ErrorBanner(_error!),

          // Preview da foto capturada.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: Image.memory(
              _photoBytes!,
              height: 360,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          if (_result == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _loading ? null : _retake,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refazer foto'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                hintText: 'Ex: pele mais seca hoje',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Enviar Registro'),
                  ),
          ],

          // Resultado.
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.ink, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Registro criado',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _RecordResultCard(record: _result!),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Ir para Home'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Botão circular translúcido (controles da câmera) ─────────────────────────

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: enabled ? 0.28 : 0.12),
              border: Border.all(color: Colors.white54, width: 1),
            ),
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.white30,
              size: 26,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(label!,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white30,
                  fontSize: 11,
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Card de resultado após criação (com polling da IA) ───────────────────────

class _RecordResultCard extends StatefulWidget {
  final Map<String, dynamic> record;
  const _RecordResultCard({required this.record});

  @override
  State<_RecordResultCard> createState() => _RecordResultCardState();
}

class _RecordResultCardState extends State<_RecordResultCard> {
  Map<String, dynamic> _record = {};
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    if (_record['ai_score'] == null) _startPolling();
  }

  Future<void> _startPolling() async {
    setState(() => _polling = true);
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final updated = await ApiService.getRecord(_record['id']);
        setState(() => _record = updated);
        if (updated['ai_score'] != null) break;
      } catch (_) {
        break;
      }
    }
    if (mounted) setState(() => _polling = false);
  }

  @override
  Widget build(BuildContext context) {
    final score = _record['ai_score'];
    final analysis = _record['ai_analysis'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (score == null)
              Row(
                children: [
                  if (_polling)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Analisando com IA...',
                      style: TextStyle(color: AppColors.muted)),
                ],
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$score',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  const SizedBox(width: 4),
                  Text('/ 10',
                      style: TextStyle(color: AppColors.muted, fontSize: 16)),
                ],
              ),
              if (analysis != null) ...[
                const Divider(),
                _AnalysisLine('Vermelhidão', analysis['redness']),
                _AnalysisLine('Acne', analysis['acne']),
                _AnalysisLine('Ressecamento', analysis['dryness']),
                _AnalysisLine('Oleosidade', analysis['oiliness']),
                const SizedBox(height: AppSpacing.sm),
                if (analysis['observations'] != null)
                  Text('${analysis['observations']}',
                      style: const TextStyle(height: 1.4)),
                if (analysis['recommendations'] != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('${analysis['recommendations']}',
                      style: TextStyle(
                          color: AppColors.muted, height: 1.4, fontSize: 13)),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AnalysisLine extends StatelessWidget {
  final String label;
  final dynamic value;
  const _AnalysisLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value?.toString() ?? '-',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
