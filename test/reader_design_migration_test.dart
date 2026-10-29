import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/core/reader/reader_design_migration.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_margin_settings.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/core/reader/reader_system_ui.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/reader_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userDataKeys = <String>[
    'book_progress',
    'reader_bookmarks',
    'reader_custom_themes_v1',
    'custom_font_files',
  ];

  test('覆盖安装时把旧排版迁移到精校基线，且不动书籍数据', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ReaderSettingsStore.fontSizeKey: 34.0,
      ReaderSettingsStore.fontWeightKey: 700,
      ReaderSettingsStore.lineHeightKey: 2.4,
      ReaderSettingsStore.horizontalMarginKey: 8.0,
      ReaderSettingsStore.themeKey: 'day',
      ReaderSettingsStore.pageModeKey: 'horizontalSlide',
      ReaderSettingsStore.chapterProgressStyleKey: 'hidden',
      ReaderSettingsStore.chapterTitlePageKey: true,
      for (final key in userDataKeys) key: 'keep',
    });

    await ReaderDesignMigration.ensureApplied();
    final prefs = await SharedPreferences.getInstance();

    expect(
      prefs.getString(ReaderSettingsStore.themeKey),
      ReaderThemes.paper.id,
    );
    expect(
      prefs.getDouble(ReaderSettingsStore.fontSizeKey),
      ReaderSettings.defaultFontSize,
    );
    expect(prefs.getInt(ReaderSettingsStore.fontWeightKey), 400);
    expect(
      prefs.getDouble(ReaderSettingsStore.lineHeightKey),
      ReaderSettings.defaultLineHeight,
    );
    expect(
      prefs.getDouble(ReaderSettingsStore.horizontalMarginKey),
      ReaderSettings.defaultHorizontalMargin,
    );
    expect(
      prefs.getDouble(ReaderSettingsStore.topMarginKey),
      ReaderMarginSettings.defaultTop,
    );
    expect(
      prefs.getDouble(ReaderSettingsStore.bottomMarginKey),
      ReaderMarginSettings.defaultBottom,
    );
    expect(
      prefs.getString(ReaderSettingsStore.textAlignmentKey),
      ReaderTextAlignment.justified.name,
    );
    expect(prefs.getInt(ReaderSettingsStore.firstLineIndentKey), 2);
    expect(prefs.getInt(ReaderSettingsStore.paragraphSpacingKey), 0);
    expect(
      prefs.getString(ReaderSettingsStore.pageModeKey),
      ReaderPageMode.coverSlide.name,
    );
    expect(
      prefs.getString(ReaderSettingsStore.chapterProgressStyleKey),
      ReaderChapterProgressStyle.fraction.name,
    );
    expect(prefs.getBool(ReaderSettingsStore.chapterTitlePageKey), isFalse);
    expect(
      prefs.getString(AppSettingsNotifier.readerFontIdKey),
      FontCatalog.serifFont.id,
    );
    expect(prefs.getInt(ReaderDesignMigration.versionKey), 2);
    expect(
      await ReaderSystemUiController.loadPreference(),
      ReaderTopBarStyle.reader,
    );

    for (final key in userDataKeys) {
      expect(prefs.getString(key), 'keep', reason: '不应清空 $key');
    }
  });

  test('新装用户读到精校默认值', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderDesignMigration.ensureApplied();

    final settings = await const ReaderSettingsStore().load();
    expect(settings.themeId, ReaderThemes.paper.id);
    expect(settings.fontSize, ReaderSettings.defaultFontSize);
    expect(settings.lineHeight, ReaderSettings.defaultLineHeight);
    expect(settings.textAlignment, ReaderTextAlignment.justified);
    expect(settings.horizontalMargin, ReaderSettings.defaultHorizontalMargin);
    expect(settings.firstLineIndent, 2);
    expect(settings.paragraphSpacing, 0);
    expect(settings.pageMode, ReaderPageMode.coverSlide);
    expect(settings.chapterProgressStyle, ReaderChapterProgressStyle.fraction);
    expect(settings.chapterTitlePageEnabled, isFalse);
  });

  test('迁移幂等：第二次启动不覆盖用户后来的调整', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderDesignMigration.ensureApplied();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(ReaderSettingsStore.fontSizeKey, 26);
    await prefs.setString(ReaderSettingsStore.themeKey, ReaderThemes.night.id);

    await ReaderDesignMigration.ensureApplied();

    expect(prefs.getDouble(ReaderSettingsStore.fontSizeKey), 26);
    expect(
      prefs.getString(ReaderSettingsStore.themeKey),
      ReaderThemes.night.id,
    );
  });

  test('恢复精校默认会覆盖当前值但不递增版本', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderDesignMigration.ensureApplied();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(ReaderSettingsStore.fontSizeKey, 26);
    await prefs.setString(ReaderSettingsStore.themeKey, ReaderThemes.night.id);

    await ReaderDesignMigration.applyDesignDefaults();

    expect(
      prefs.getDouble(ReaderSettingsStore.fontSizeKey),
      ReaderSettings.defaultFontSize,
    );
    expect(
      prefs.getString(ReaderSettingsStore.themeKey),
      ReaderThemes.paper.id,
    );
    expect(prefs.getInt(ReaderDesignMigration.versionKey), 2);
  });
}
