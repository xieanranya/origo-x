import 'package:flutter/material.dart';

/// 3px 细轨道 + 14px 白心描边圆点的极简滑杆。
///
/// 不用 Material [Slider]：默认的 overlay 光晕、48px 最小高度和纯色拇指会让
/// 阅读面板重新变回开源 App 的样子。这里直接画轨道与拇指，尺寸与
/// `hybrid.html` 的 `input[type=range]` 对齐。
class ReaderThinSlider extends StatelessWidget {
  const ReaderThinSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbFill,
    required this.thumbBorder,
    this.onChangeEnd,
    this.height = 22,
    this.trackHeight = 3,
    this.thumbRadius = 7,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbFill;
  final Color thumbBorder;
  final double height;
  final double trackHeight;
  final double thumbRadius;
  final String? semanticLabel;

  void _emit(double dx, double width) {
    if (width <= 0) return;
    final usable = width - thumbRadius * 2;
    if (usable <= 0) return;
    final ratio = ((dx - thumbRadius) / usable).clamp(0.0, 1.0);
    onChanged(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          slider: true,
          label: semanticLabel,
          value: '${(value * 100).round()}%',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _emit(details.localPosition.dx, width),
            onHorizontalDragStart: (details) =>
                _emit(details.localPosition.dx, width),
            onHorizontalDragUpdate: (details) =>
                _emit(details.localPosition.dx, width),
            onHorizontalDragEnd: (_) => onChangeEnd?.call(value),
            child: SizedBox(
              height: height,
              width: width,
              child: CustomPaint(
                painter: _ThinSliderPainter(
                  value: value.clamp(0.0, 1.0).toDouble(),
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  thumbFill: thumbFill,
                  thumbBorder: thumbBorder,
                  trackHeight: trackHeight,
                  thumbRadius: thumbRadius,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThinSliderPainter extends CustomPainter {
  const _ThinSliderPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbFill,
    required this.thumbBorder,
    required this.trackHeight,
    required this.thumbRadius,
  });

  final double value;
  final Color activeColor;
  final Color inactiveColor;
  final Color thumbFill;
  final Color thumbBorder;
  final double trackHeight;
  final double thumbRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final start = thumbRadius;
    final end = size.width - thumbRadius;
    if (end <= start) return;
    final trackPaint = Paint()
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;
    final inactiveRect = Rect.fromLTWH(
      start,
      centerY - trackHeight / 2,
      end - start,
      trackHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, Radius.circular(trackHeight / 2)),
      trackPaint..color = inactiveColor,
    );
    final thumbX = start + (end - start) * value;
    if (thumbX > start) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            start,
            centerY - trackHeight / 2,
            thumbX - start,
            trackHeight,
          ),
          Radius.circular(trackHeight / 2),
        ),
        trackPaint..color = activeColor,
      );
    }
    // 拇指：白心 + 2px 描边 + 轻微投影，和 HTML 的 range thumb 一致。
    canvas.drawCircle(
      Offset(thumbX, centerY + 1),
      thumbRadius,
      Paint()
        ..color = const Color(0x2E000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      Offset(thumbX, centerY),
      thumbRadius,
      Paint()..color = thumbFill,
    );
    canvas.drawCircle(
      Offset(thumbX, centerY),
      thumbRadius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = thumbBorder,
    );
  }

  @override
  bool shouldRepaint(covariant _ThinSliderPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.thumbFill != thumbFill ||
      oldDelegate.thumbBorder != thumbBorder;
}
