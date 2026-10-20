import 'dart:io';

import 'package:flutter/material.dart';

Widget buildReaderThemeBackgroundImage(String imagePath) {
  // 内置主题的纸张图打包在 assets 里，用户自定义主题才是本地文件。
  if (imagePath.startsWith('assets/')) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(imagePath),
    fit: BoxFit.cover,
    filterQuality: FilterQuality.medium,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
