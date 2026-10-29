import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// 纸黄主题的极淡纸纹：5px 网格圆点，透明度约 3%。
///
/// 只用 `drawPoints` 一次提交，不做随机、不依赖时间，`shouldRepaint` 恒为
/// false，并包在 [RepaintBoundary] + [IgnorePointer] 里，翻页时不会重绘。
class ReaderPaperTexture extends StatelessWidget {
  const ReaderPaperTexture({
    super.key,
    required this.color,
    this.opacity = 0.03,
    this.grid = 5,
    this.dotRadius = 0.55,
  });

  final Color color;
  final double opacity;
  final double grid;
  final double dotRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ReaderPaperDotsPainter(
            color: color.withValues(alpha: opacity),
            grid: grid,
            dotRadius: dotRadius,
          ),
          isComplex: false,
          willChange: false,
        ),
      ),
    );
  }
}

class _ReaderPaperDotsPainter extends CustomPainter {
  const _ReaderPaperDotsPainter({
    required this.color,
    required this.grid,
    required this.dotRadius,
  });

  final Color color;
  final double grid;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || grid <= 0) return;
    final points = <Offset>[];
    for (var y = grid / 2; y < size.height; y += grid) {
      for (var x = grid / 2; x < size.width; x += grid) {
        points.add(Offset(x, y));
      }
    }
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = dotRadius * 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _ReaderPaperDotsPainter oldDelegate) => false;
}
