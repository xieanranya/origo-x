// 文件说明：易读「墨韵」国风设计令牌（颜色 / 字体 / 字号 / 圆角 / 阴影）。
// 设计来源：ui-preview/moyun-ui-final.html 定稿的墨韵古风体系。
//   纸 #F7F4EC / 卡 #FFFDF8 / 墨 #26261F / 松绿 #2F5D50 / 朱红 #B03A2E / 金 #B9975B
//   夜：#1A1D1A 底 / #262B26 卡 / #E6E2D4 字 / #8FB8A3 松绿 / #C9604F 朱红
// 强调色仍跟随用户选择（ThemeNotifier.accentColor），默认已改为松绿。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/core/theme_notifier.dart';

/// 全局衬线字体族（思源宋体，随包分发，SIL OFL）。
class AppFont {
  const AppFont._();

  static const String serif = 'NotoSerifSC';

  /// 备用：设备没加载到字体时退回系统衬线。
  static const List<String> fallback = <String>[
    'Source Han Serif SC',
    'Songti SC',
    'STSong',
    'SimSun',
    'serif',
  ];

  static const TextStyle base = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: fallback,
  );
}

/// 外壳统一配色。用 [AppPalette.of] 在 build 里取，深色/浅色自动切换。
@immutable
class AppPalette {
  const AppPalette._({required this.dark, required this.accent});

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

  /// 页面底色（宣纸外裱）。
  Color get bg => dark ? const Color(0xFF151815) : const Color(0xFFF1ECE0);

  /// 主纸面：页面主体可铺的纸色。
  Color get paper => dark ? const Color(0xFF20241F) : const Color(0xFFF7F4EC);

  /// 卡片 / 列表容器底色（近白宣纸）。
  Color get surface => dark ? const Color(0xFF262B26) : const Color(0xFFFFFDF8);

  /// 半透明浮层（悬浮底栏、胶囊顶栏）。
  Color get float => dark ? const Color(0xF2262B26) : const Color(0xF2FFFDF8);

  /// 次级填充：搜索框、chip、进度条槽。
  Color get fill => dark ? const Color(0xFF2E342E) : const Color(0xFFEDE7D8);

  /// 主文字（墨）。
  Color get text => dark ? const Color(0xFFE6E2D4) : const Color(0xFF26261F);

  /// 次要文字。
  Color get text2 => dark ? const Color(0xFFB4B0A2) : const Color(0xFF55554A);

  /// 弱文字（作者、说明、图标）。
  Color get text3 => dark ? const Color(0xFF7C8074) : const Color(0xFF97978A);

  /// 分隔线 / 细描边。
  Color get line => dark ? const Color(0x1FE6E2D4) : const Color(0x1426261F);

  /// 略重的描边（纸卡边）。
  Color get hairline =>
      dark ? const Color(0x2EE6E2D4) : const Color(0x1F26261F);

  /// 松绿：国风主色（不随用户强调色变，用于装饰与印章）。
  Color get pine => dark ? const Color(0xFF8FB8A3) : const Color(0xFF2F5D50);

  /// 松绿浅底。
  Color get pineSoft =>
      dark ? const Color(0xFF2C3A33) : const Color(0xFFE3EDE7);

  /// 朱红：未读角标、危险操作、印章。
  Color get cinnabar =>
      dark ? const Color(0xFFC9604F) : const Color(0xFFB03A2E);

  /// 金：细分隔装饰、卷轴点缀。
  Color get gold => dark ? const Color(0xFFC8A970) : const Color(0xFFB9975B);

  /// 强调色浅底（按钮底、图标块底）。
  Color get accentSoft => accent.withValues(alpha: dark ? 0.16 : 0.10);

  /// 卡片阴影：纸片轻浮起，深色只留最轻的一层。
  List<BoxShadow> get cardShadow => dark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1226261F),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ];

  /// 悬浮元素阴影（底栏、浮动按钮）。
  List<BoxShadow> get floatShadow => dark
      ? const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x2626261F),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ];
}

/// 外壳统一字号。中文用宽字距，行高 1.3~1.45。
class AppText {
  const AppText._();

  /// 页面标题：26 / 700，字距 2（国风标题要「站得住」）。
  static const TextStyle pageTitle = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    height: 1.25,
  );

  /// 章节/大标题：22 / 700，字距 1.5。
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    height: 1.35,
  );

  /// 卡片书名：15 / 600，字距 0.6。
  static const TextStyle bookName = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.4,
  );

  /// 卡片作者：11 弱文字色，字距 0.8。
  static const TextStyle bookAuthor = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 11,
    letterSpacing: 0.8,
    height: 1.35,
  );

  /// 列表主文案：14.5 / 500。
  static const TextStyle rowTitle = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    height: 1.35,
  );

  /// 列表副文案：12。
  static const TextStyle rowSub = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 12,
    letterSpacing: 0.4,
    height: 1.35,
  );

  /// 分组小标题：11.5 / 600，字距 2。
  static const TextStyle groupLabel = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    height: 1.3,
  );

  /// 说明/注释：11，字距 1。
  static const TextStyle caption = TextStyle(
    fontFamily: AppFont.serif,
    fontFamilyFallback: AppFont.fallback,
    fontSize: 11,
    letterSpacing: 1,
    height: 1.5,
  );
}

/// 常用圆角。
class AppRadius {
  const AppRadius._();

  static const double card = 20;
  static const double tile = 14;
  static const double cover = 10;
  static const double chip = 999;
  static const double field = 16;
  static const double sheet = 28;
}
