import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../services/core/app_settings_service.dart';
import '../../utils/font_catalog_helper.dart';
import '../../utils/reader_themes.dart';
import 'reader_header_footer_settings.dart';
import 'reader_margin_settings.dart';
import 'reader_settings.dart';
import 'reader_system_ui.dart';

/// 阅读页视觉重构（v2）的一次性设计迁移。
///
/// 只写「阅读外观」相关的偏好键：字号 / 字重 / 主题 / 行高 / 边距 / 字体 /
/// 页眉页脚。书籍进度、书签、笔记、自定义主题、自定义字体文件一律不碰，
/// 因此覆盖安装后读到的是新基线，而不是被旧 SharedPreferences 锁住的旧样式。
abstract final class ReaderDesignMigration {
  static const int designVersion = 2;
  static const String versionKey = 'reader_design_version_v2';

  /// 版本检查后应用；幂等：已迁移过直接返回，不覆盖用户后来的调整。
  static Future<void> ensureApplied() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(versionKey) ?? 0) >= designVersion) return;
    await applyDesignDefaults(prefs: prefs);
    await prefs.setInt(versionKey, designVersion);
  }

  /// 无条件写入精校默认值；「恢复精校默认」按钮也走这里。
  ///
  /// 不递增 [versionKey]，避免把用户之后的手动调整当成需要回滚的旧数据。
  static Future<void> applyDesignDefaults({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      store.setString(ReaderSettingsStore.themeKey, ReaderThemes.paper.id),
      store.setDouble(
        ReaderSettingsStore.fontSizeKey,
        ReaderSettings.defaultFontSize,
      ),
      store.setInt(
        ReaderSettingsStore.fontWeightKey,
        ReaderSettings.defaultFontWeight,
      ),
      store.setDouble(
        ReaderSettingsStore.lineHeightKey,
        ReaderSettings.defaultLineHeight,
      ),
      store.setDouble(
        ReaderSettingsStore.letterSpacingKey,
        ReaderSettings.defaultLetterSpacing,
      ),
      store.setString(
        ReaderSettingsStore.textAlignmentKey,
        ReaderSettings.defaultTextAlignment.name,
      ),
      store.setDouble(
        ReaderSettingsStore.horizontalMarginKey,
        ReaderSettings.defaultHorizontalMargin,
      ),
      store.setDouble(
        ReaderSettingsStore.topMarginKey,
        ReaderMarginSettings.defaultTop,
      ),
      store.setDouble(
        ReaderSettingsStore.bottomMarginKey,
        ReaderMarginSettings.defaultBottom,
      ),
      store.setInt(
        ReaderSettingsStore.firstLineIndentKey,
        ReaderSettings.defaultFirstLineIndent,
      ),
      store.setInt(
        ReaderSettingsStore.paragraphSpacingKey,
        ReaderSettings.defaultParagraphSpacing,
      ),
      store.setInt(
        ReaderSettingsStore.textBrightnessKey,
        ReaderSettings.defaultTextBrightness,
      ),
      store.setString(
        ReaderSettingsStore.pageModeKey,
        ReaderSettings.defaultPageMode.name,
      ),
      store.setString(
        ReaderSettingsStore.chapterProgressStyleKey,
        ReaderSettings.defaultChapterProgressStyle.name,
      ),
      store.setBool(
        ReaderSettingsStore.chapterTitlePageKey,
        ReaderSettings.defaultChapterTitlePageEnabled,
      ),
      store.setString(
        ReaderSettingsStore.headerFooterKey,
        jsonEncode(const ReaderHeaderFooterSettings().toJson()),
      ),
      store.setString(
        AppSettingsNotifier.readerFontIdKey,
        FontCatalog.serifFont.id,
      ),
    ]);
    await ReaderSystemUiController.savePreference(ReaderTopBarStyle.reader);
    // 启动时调用的场合还没有缓存；「恢复精校默认」调用时缓存可能已是旧主题。
    ReaderThemes.invalidateSavedPaletteCache();
  }
}
