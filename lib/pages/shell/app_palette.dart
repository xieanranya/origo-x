// 文件说明：新版外壳的视觉令牌（颜色 / 字号 / 圆角 / 阴影）。
// 对齐设计稿 novel-ui-preview/index.html：浅色 #F5F6F8 底 + 纯白卡片，深色纯黑底 + #141416 卡片。
// 强调色不写死，统一取 ThemeNotifier().accentColor，跟随用户已选的主题色。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/core/theme_notifier.dart';

/// 外壳统一配色。用 [AppPalette.of] 在 build 里取，深色/浅色自动切换。
@immutable
class AppPalette {
  const AppPalette._({
    required this.dark,
    required this.accent,
  });

  final bool dark;

  /// 强调色（来自 ThemeNotifier，不硬编码）。
  final Color accent;

  factory AppPalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color accent;
    try {
      accent = Provider.of<ThemeNotifier>(context).accentColor;
    } catch (_) {
      // 没有 Provider（例如单独预览某个组件）时退回主题主色。
      accent = Theme.of(context).colorScheme.primary;
    }
    return AppPalette._(dark: dark, accent: accent);
  }

  /// 页面底色。
  Color get bg => dark ? const Color(0xFF000000) : const Color(0xFFF5F6F8);

  /// 卡片 / 列表容器底色。
  Color get surface =>
      dark ? const Color(0xFF141416) : const Color(0xFFFFFFFF);

  /// 次级填充：搜索框、chip、进度条槽。
  Color get fill => dark ? const Color(0xFF1E1E22) : const Color(0xFFEFF1F4);

  /// 主文字。
  Color get text => dark ? const Color(0xFFF2F3F5) : const Color(0xFF16181D);

  /// 次要文字。
  Color get text2 => dark ? const Color(0xFF9BA1AC) : const Color(0xFF6B7280);

  /// 弱文字（作者、说明、图标）。
  Color get text3 => dark ? const Color(0xFF6A7079) : const Color(0xFF9AA1AC);

  /// 分隔线。
  Color get line => dark
      ? Colors.white.withValues(alpha: 0.085)
      : Colors.black.withValues(alpha: 0.065);

  /// 强调色浅底（按钮底、图标块底）。
  Color get accentSoft => accent.withValues(alpha: dark ? 0.14 : 0.10);

  /// 卡片阴影：深色只留最轻的一层。
  List<BoxShadow> get cardShadow => dark
      ? const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ];
}

/// 外壳统一字号。中文不加额外字距，行高统一 1.25~1.4。
class AppText {
  const AppText._();

  /// 页面标题：27 / 700，字距 -0.4。
  static const TextStyle pageTitle = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.15,
  );

  /// 卡片书名：13 / 600。
  static const TextStyle bookName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// 卡片作者：10.5 弱文字色。
  static const TextStyle bookAuthor = TextStyle(fontSize: 10.5, height: 1.3);

  /// 列表主文案：14.5 / 500。
  static const TextStyle rowTitle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// 列表副文案：12.5。
  static const TextStyle rowSub = TextStyle(fontSize: 12.5, height: 1.3);

  /// 分组小标题：12 / 600。
  static const TextStyle groupLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );
}

/// 常用圆角。
class AppRadius {
  const AppRadius._();

  static const double card = 16;
  static const double tile = 14;
  static const double cover = 11;
  static const double chip = 999;
  static const double field = 12;
}
