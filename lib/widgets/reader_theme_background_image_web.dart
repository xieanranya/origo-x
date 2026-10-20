import 'package:flutter/material.dart';

Widget buildReaderThemeBackgroundImage(String imagePath) {
  // Web 端没有本地文件，但内置主题的 assets 纸张图可用。
  if (imagePath.startsWith('assets/')) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return const SizedBox.shrink();
}
