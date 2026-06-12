import 'package:flutter/material.dart';

/// Desenha um scrim escuro sobre toda a tela, com um recorte oval transparente
/// no centro e uma borda branca fina ao redor — o guia de posicionamento do rosto.
class FaceOvalPainter extends CustomPainter {
  /// Proporção da largura da tela ocupada pelo oval (0–1).
  final double widthFactor;

  /// Razão altura/largura do oval (rosto é mais alto que largo).
  final double aspect;

  /// Opacidade do scrim escuro.
  final double scrimOpacity;

  const FaceOvalPainter({
    this.widthFactor = 0.72,
    this.aspect = 1.32,
    this.scrimOpacity = 0.55,
  });

  Rect _ovalRect(Size size) {
    final ovalWidth = size.width * widthFactor;
    final ovalHeight = ovalWidth * aspect;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: ovalWidth,
      height: ovalHeight,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = _ovalRect(size);

    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);

    // Scrim com recorte oval (difference).
    final scrim = Path.combine(PathOperation.difference, screenPath, ovalPath);
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: scrimOpacity),
    );

    // Borda branca fina ao redor do oval.
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant FaceOvalPainter oldDelegate) =>
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.aspect != aspect ||
      oldDelegate.scrimOpacity != scrimOpacity;
}
