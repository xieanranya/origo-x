// 文件说明：统一封面画法。有图用图，没图就按书名生成固定渐变 + 首字，
// 保证同一本书每次渲染出来的颜色一致（不是随机色）。
import 'dart:io';

import 'package:flutter/material.dart';

/// 由标题算出稳定的色相种子。
int coverSeed(String title) {
  var seed = 0;
  for (final unit in title.codeUnits) {
    seed = (seed * 31 + unit) & 0x7fffffff;
  }
  return seed;
}

/// 渐变两端颜色。
List<Color> coverGradient(String title) {
  final hue = (coverSeed(title) % 360).toDouble();
  return [
    HSLColor.fromAHSL(1, hue, 0.40, 0.26).toColor(),
    HSLColor.fromAHSL(1, (hue + 26) % 360, 0.52, 0.50).toColor(),
  ];
}

/// 封面上显示的字（书名首字）。
String coverGlyph(String title) {
  final text = title.trim();
  if (text.isEmpty) return '书';
  return String.fromCharCode(text.runes.first);
}

/// 封面：图片优先，否则渐变 + 首字。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.title,
    this.path,
    this.radius = 8,
    this.glyphSize = 20,
  });

  final String title;
  final String? path;
  final double radius;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final file = path;
    Widget inner;
    if (file != null && file.isNotEmpty && _exists(file)) {
      inner = Image.file(
        File(file),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _art(),
      );
    } else {
      inner = _art();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: inner);
  }

  Widget _art() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: coverGradient(title),
        ),
      ),
      child: Center(
        child: Text(
          coverGlyph(title),
          style: TextStyle(
            fontSize: glyphSize,
            fontWeight: FontWeight.w700,
            color: const Color(0xEBFFFFFF),
            shadows: const [
              Shadow(
                color: Color(0x47000000),
                blurRadius: 14,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _exists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
