import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_header_footer_settings.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/pages/shelf/shelf_page.dart';
import 'package:xxread/pages/shell/app_palette.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_reading_chrome.dart';
import 'package:xxread/widgets/reader_settings_controls.dart';
import 'package:xxread/widgets/reader_theme_background.dart';

/// 生成 390×844 预览图，用来核对视觉是否真的离开了旧 UI。
///
/// 运行：flutter test tool/preview/reader_preview_test.dart
/// 产物：build/preview/reader-page.png、settings-sheet.png
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('Roboto', 'C:/Windows/Fonts/STSONG.TTF');
    await _loadFont('Ahem', 'C:/Windows/Fonts/STSONG.TTF');
    await _loadFont('STSong', 'C:/Windows/Fonts/STSONG.TTF');
    // 墨韵国风：预览必须用随包的思源宋体，才能看出真实观感。
    await _loadFont(
      AppFont.serif,
      'assets/fonts/NotoSerifSC-Regular.otf',
    );
    await _loadFont(
      'MaterialIcons',
      'F:/devtools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
  });

  testWidgets('render reader page preview', (tester) async {
    await _pumpAt390(tester, const _ReadingPage());
    await tester.pumpAndSettle();
    await _capture(tester, 'reader-page.png');
  });

  testWidgets('render shelf preview', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return Directory.systemTemp.createTempSync('preview-shelf-').path;
    });
    await _pumpAt390(
      tester,
      Scaffold(
        backgroundColor: const Color(0xFFF1ECE0),
        body: const ShelfPage(),
        bottomNavigationBar: _FloatingTabBarShim(),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint(
      'shelf debug: loading=${find.byType(CircularProgressIndicator).evaluate().length} '
      'empty=${find.textContaining('书架').evaluate().length} '
      'title=${find.text('我的书架').evaluate().length}',
    );
    await _capture(tester, 'shelf.png');
  });

  testWidgets('render settings sheet preview', (tester) async {
    await _pumpAt390(tester, const _SettingsPreview());
    await tester.pumpAndSettle();
    await _capture(tester, 'settings-sheet.png');
  });
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final loader = FontLoader(family)
    ..addFont(
      Future<ByteData>.value(
        ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync())),
      ),
    );
  await loader.load();
}

Future<void> _pumpAt390(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: RepaintBoundary(
        key: const ValueKey('shot'),
        child: SizedBox(width: 390, height: 844, child: child),
      ),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/preview/$name');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

class _ReadingPage extends StatelessWidget {
  const _ReadingPage();

  static const _paragraphs = <String>[
    '雨是后半夜落下来的。瓦檐上先是零零散散的几点，像谁在屋顶上试探着敲了几下，随后便连成一片，密密地顺着沟瓦往下淌。',
    '沈砚起身关窗，指尖碰到木框时，湿凉的气息顺着袖口钻进来。院子里的老槐树被风推得低了头，叶子背面翻出灰白，一层一层地涌过去。',
    '他想起许多年前也是这样的雨夜，母亲在灯下替他补那件洗得发白的青布衫。针脚很密，密到灯光都被缝进了布里。',
  ];

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      inherit: false,
      fontFamily: 'STSong',
      fontSize: 19,
      height: 1.85,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF2B2A26),
    );
    const small = TextStyle(
      inherit: false,
      fontFamily: 'STSong',
      fontSize: 10,
      height: 1,
      color: Color(0xFF9A9184),
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return ReaderThemeBackground(
      palette: ReaderThemes.paper,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 44 + 8, 22, 24 + 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('09:41', style: small),
                      const Expanded(
                        child: Text(
                          '第十二章 · 雨夜',
                          textAlign: TextAlign.center,
                          style: small,
                        ),
                      ),
                      Text('100%', style: small),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '第十二章 · 雨夜',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: 'STSong',
                      fontSize: 26,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: Color(0xFF2B2A26),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        maxHeight: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final p in _paragraphs)
                              Text.rich(
                                TextSpan(text: '　　$p', style: body),
                                textAlign: TextAlign.justify,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text('12 / 68 章', style: small),
                      const Spacer(),
                      Text('5 / 25', style: small),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ReaderReadingChrome(
            palette: ReaderThemes.paper,
            visible: true,
            bookTitle: '春山夜雨',
            chapterTitle: '第十二章 · 雨夜',
            pageProgress: 0.2,
            pageLabel: '5 / 25',
            bookmarked: true,
            readAloudActive: false,
            onBack: () {},
            onBookmark: () {},
            onPreviousChapter: () {},
            onNextChapter: () {},
            onPageProgressChanged: (_) {},
            onTableOfContents: () {},
            onReadAloud: () {},
            onNightMode: () {},
            onSettings: () {},
            onMore: () {},
            backTooltip: '返回',
            bookmarkTooltip: '书签',
            tableOfContentsTooltip: '目录',
            readAloudTooltip: '听书',
            settingsTooltip: '设置',
            nightModeTooltip: '夜间',
            previousChapterTooltip: '上一章',
            nextChapterTooltip: '下一章',
          ),
        ],
      ),
    );
  }
}

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return ReaderThemeBackground(
          palette: ReaderThemes.paper,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 390,
                  child: ReaderSettingsSheet(
                    title: l10n.readingSettings,
                    tabThemeLabel: l10n.readerSettingsTabTheme,
                    tabTextLabel: l10n.readerSettingsTabText,
                    tabLayoutLabel: l10n.readerSettingsTabLayout,
                    advancedTypographyTitle:
                        l10n.readerSettingsAdvancedTypography,
                    themeDescription: l10n.readerThemeDescription,
                    pageModeTitle: l10n.pageTurningMode,
                    pageModeSummary: l10n.readerModeCoverSlideHint,
                    topBarStyleTitle: l10n.readerTopBarStyleTitle,
                    topBarStyleSummary: l10n.readerTopBarStyleReader,
                    pullBookmarkTitle: l10n.readerPullBookmarkTitle,
                    pullBookmarkHint: l10n.readerPullBookmarkHint,
                    tapPageAnimationTitle: l10n.readerTapAnimationTitle,
                    tapPageAnimationHint: l10n.readerTapAnimationHint,
                    tapZonesTitle: l10n.tapZoneSettings,
                    tapZonesHint: l10n.tapZoneSettingsHint,
                    showTabletTwoPageToggle: false,
                    tabletTwoPageTitle: l10n.readerTabletTwoPageTitle,
                    tabletTwoPageHint: l10n.readerTabletTwoPageHint,
                    fontFamilyLabel: l10n.fontFamilyLabel,
                    fontFamilyValueLabel: '宋体',
                    fontFamilyHint: l10n.fontSerifDescription,
                    onFontFamilyTap: () async => null,
                    fontSizeLabel: l10n.fontSizeLabel,
                    textBrightnessLabel: l10n.readerTextBrightnessLabel,
                    dimTextInDarkModeTitle: l10n.readerDimTextInDarkModeTitle,
                    dimTextInDarkModeHint: l10n.readerDimTextInDarkModeHint,
                    fontWeightLabel: l10n.readerFontWeightLabel,
                    fontWeightValueLabels: <String>[
                      l10n.readerFontWeightLight,
                      l10n.readerFontWeightRegular,
                      l10n.readerFontWeightMedium,
                      l10n.readerFontWeightSemiBold,
                      l10n.readerFontWeightBold,
                    ],
                    fontWeightHint: l10n.readerFontWeightSyntheticHint,
                    fontWeightPreviewText: l10n.readerFontWeightPreview,
                    lineHeightLabel: l10n.lineSpacingLabel,
                    letterSpacingLabel: l10n.letterSpacingLabel,
                    textAlignmentLabel: l10n.textAlignmentLabel,
                    textAlignmentNaturalLabel: l10n.textAlignmentNatural,
                    textAlignmentJustifiedLabel: l10n.textAlignmentJustified,
                    firstLineIndentLabel: l10n.firstLineIndentLabel,
                    paragraphSpacingLabel: l10n.paragraphSpacingLabel,
                    horizontalMarginLabel: l10n.readerHorizontalMarginLabel,
                    topMarginLabel: l10n.readerTopMarginLabel,
                    bottomMarginLabel: l10n.readerBottomMarginLabel,
                    chapterTitlePageTitle: l10n.readerTxtChapterTitlePageTitle,
                    chapterTitlePageHint: l10n.readerTxtChapterTitlePageHint,
                    showChapterTitlePageToggle: true,
                    themeId: ReaderThemes.paper.id,
                    fontSize: ReaderSettings.defaultFontSize,
                    textBrightness: ReaderSettings.defaultTextBrightness,
                    dimTextInDarkMode: ReaderSettings.defaultDimTextInDarkMode,
                    fontWeight: ReaderSettings.defaultFontWeight,
                    fontFamily: 'STSong',
                    lineHeight: ReaderSettings.defaultLineHeight,
                    letterSpacing: ReaderSettings.defaultLetterSpacing,
                    textAlignment: ReaderSettings.defaultTextAlignment,
                    firstLineIndent: ReaderSettings.defaultFirstLineIndent,
                    paragraphSpacing: ReaderSettings.defaultParagraphSpacing,
                    horizontalMargin: ReaderSettings.defaultHorizontalMargin,
                    topMargin: 8,
                    bottomMargin: 10,
                    pullBookmarkEnabled: false,
                    tapPageAnimationEnabled: true,
                    tabletTwoPageEnabled: false,
                    chapterTitlePageEnabled: false,
                    themeLabelFor: (id) => switch (id) {
                      'paper' => '宣纸',
                      'moyun_yuebai' => '月白',
                      'moyun_zhuqing' => '竹青',
                      'moyun_yunmu' => '云母',
                      'moyun_dailan' => '黛蓝',
                      'moyun_taoyao' => '桃夭',
                      'moyun_ye' => '墨韵夜',
                      'day' => '白天',
                      'green' => '护眼',
                      'night' => '黑夜',
                      _ => '自定义',
                    },
                    onThemeChanged: (_) {},
                    onCustomThemeTap: () {},
                    onPageModeTap: () {},
                    onTopBarStyleTap: () {},
                    onTapZonesTap: () {},
                    onFontSizeChanged: (_) {},
                    onTextBrightnessChanged: (_) {},
                    onDimTextInDarkModeChanged: (_) {},
                    onFontWeightChanged: (_) {},
                    onLineHeightChanged: (_) {},
                    onLetterSpacingChanged: (_) {},
                    onTextAlignmentChanged: (_) {},
                    onFirstLineIndentChanged: (_) {},
                    onParagraphSpacingChanged: (_) {},
                    onHorizontalMarginChanged: (_) {},
                    onTopMarginChanged: (_) {},
                    onBottomMarginChanged: (_) {},
                    onPullBookmarkChanged: (_) {},
                    onTapPageAnimationChanged: (_) {},
                    onTabletTwoPageChanged: (_) {},
                    onChapterTitlePageChanged: (_) {},
                    headerFooter: const ReaderHeaderFooterSettings(),
                    headerFooterLabels: ReaderHeaderFooterLabels(
                      tabLabel: l10n.readerSettingsTabHeaderFooter,
                      headerSectionTitle: l10n.readerHeaderSectionTitle,
                      headerEnabledTitle: l10n.readerHeaderEnabledTitle,
                      headerEnabledHint: l10n.readerHeaderEnabledHint,
                      headerChapterContent: l10n.readerHeaderChapterContent,
                      headerBookContent: l10n.readerHeaderBookContent,
                      headerTimeContent: l10n.readerHeaderTimeContent,
                      headerBatteryContent: l10n.readerHeaderBatteryContent,
                      headerPositionLabel: l10n.readerHeaderPositionLabel,
                      headerFontSizeLabel: l10n.readerHeaderFontSizeLabel,
                      headerTopBarHint: l10n.readerHeaderTopBarHint,
                      footerSectionTitle: l10n.readerFooterSectionTitle,
                      footerEnabledTitle: l10n.readerFooterEnabledTitle,
                      footerEnabledHint: l10n.readerFooterEnabledHint,
                      footerChapterContent: l10n.readerFooterChapterContent,
                      footerPageContent: l10n.readerFooterPageContent,
                      footerPercentContent: l10n.readerFooterPercentContent,
                      footerRemainingContent: l10n.readerFooterRemainingContent,
                      footerPositionLabel: l10n.readerFooterPositionLabel,
                      footerFontSizeLabel: l10n.readerFooterFontSizeLabel,
                      positionSplit: l10n.readerChromePositionSplit,
                      positionLeft: l10n.readerChromePositionLeft,
                      positionCenter: l10n.readerChromePositionCenter,
                      positionRight: l10n.readerChromePositionRight,
                    ),
                    onHeaderFooterChanged: (_) {},
                    doneLabel: l10n.readerHeaderFooterDone,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 预览专用：直接复用真实底栏会牵出 Provider 依赖，这里画一个等价的。
class _FloatingTabBarShim extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xF2FFFDF8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x1F26261F)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2626261F),
              blurRadius: 34,
              offset: Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final item in const [
              (Icons.auto_stories, '书架', true),
              (Icons.travel_explore_outlined, '发现', false),
              (Icons.person_outline_rounded, '我的', false),
            ])
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$1,
                      size: 21,
                      color: item.$3
                          ? const Color(0xFF2F5D50)
                          : const Color(0xFF97978A),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 2,
                        fontWeight: item.$3
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: item.$3
                            ? const Color(0xFF2F5D50)
                            : const Color(0xFF97978A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
