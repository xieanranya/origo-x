import 'package:flutter/material.dart';

import '../utils/reader_themes.dart';
import 'reader_paper_texture.dart';
import 'reader_theme_background_image.dart';

class ReaderThemeBackground extends StatelessWidget {
  const ReaderThemeBackground({
    super.key,
    required this.palette,
    required this.child,
    this.borderRadius,
  });

  final ReaderThemePalette palette;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget result = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: palette.background)),
        if (palette.hasBackgroundImage)
          Positioned.fill(
            child: Opacity(
              // 不透明纸张图（内置水墨主题）需要满值渲染，
              // 否则底色会透上来把图洗淡；用户自定义的不透明度仍然原样生效。
              opacity: palette.backgroundImageOpacity.clamp(0.0, 1.0),
              child: buildReaderThemeBackgroundImage(
                palette.backgroundImagePath!,
              ),
            ),
          ),
        if (palette.id == ReaderThemes.paper.id)
          Positioned.fill(child: ReaderPaperTexture(color: palette.text)),
        child,
      ],
    );
    if (borderRadius != null) {
      result = ClipRRect(borderRadius: borderRadius!, child: result);
    }
    return result;
  }
}
