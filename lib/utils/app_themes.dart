// 文件说明：应用主题定义文件，使用单一强调色生成完整 Material 3 色板。
// 墨韵改版：默认强调色改为松绿，快捷色盘替换为 12 个国风色。
// 技术要点：ColorScheme.fromSeed、历史主题配置迁移。
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme({
    required this.seedColor,
    required this.lightColorScheme,
    required this.darkColorScheme,
  });

  final Color seedColor;
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;
}

class AppThemes {
  /// 松绿：墨韵国风的默认主色。
  static const Color defaultAccentColor = Color(0xFF2F5D50);

  /// 设置页中的快捷强调色，全部取自国画颜料。
  static const List<Color> accentColors = [
    Color(0xFF2F5D50), // 松绿
    Color(0xFF3E5C76), // 黛蓝
    Color(0xFF1F4E5F), // 靛青
    Color(0xFF7D5A50), // 赭石
    Color(0xFFB03A2E), // 绛红（朱砂）
    Color(0xFFC1743A), // 琥珀
    Color(0xFFB9975B), // 藤黄（金）
    Color(0xFF6E7A5A), // 竹青
    Color(0xFF5B5B66), // 黛灰
    Color(0xFF6A4C6E), // 藕荷
    Color(0xFF8C4A5B), // 胭脂
    Color(0xFF4A4A42), // 墨灰
  ];

  static final Map<int, String> _accentColorNames = {
    const Color(0xFF2F5D50).toARGB32(): 'pine',
    const Color(0xFF3E5C76).toARGB32(): 'daiBlue',
    const Color(0xFF1F4E5F).toARGB32(): 'indigo',
    const Color(0xFF7D5A50).toARGB32(): 'ochre',
    const Color(0xFFB03A2E).toARGB32(): 'cinnabar',
    const Color(0xFFC1743A).toARGB32(): 'amber',
    const Color(0xFFB9975B).toARGB32(): 'gold',
    const Color(0xFF6E7A5A).toARGB32(): 'bamboo',
    const Color(0xFF5B5B66).toARGB32(): 'inkGrey',
    const Color(0xFF6A4C6E).toARGB32(): 'lotus',
    const Color(0xFF8C4A5B).toARGB32(): 'rouge',
    const Color(0xFF4A4A42).toARGB32(): 'ink',
  };

  static AppTheme fromAccentColor(Color seedColor) {
    return AppTheme(
      seedColor: seedColor,
      lightColorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      darkColorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }

  /// 保留旧方法名，避免一次性破坏仍在使用的调用方。
  static AppTheme createCustomTheme(Color seedColor) =>
      fromAccentColor(seedColor);

  /// 将旧版“应用主题”名称折叠为统一强调色，用于首次升级迁移。
  static Color accentColorForLegacyTheme(String? name) {
    return switch (name) {
      'purple' => const Color(0xFF6A4C6E),
      'green' => const Color(0xFF2F5D50),
      'orange' => const Color(0xFFC1743A),
      'red' => const Color(0xFFB03A2E),
      _ => defaultAccentColor,
    };
  }

  static String getAccentColorName(Color color) {
    return _accentColorNames[color.toARGB32()] ?? 'custom';
  }
}
