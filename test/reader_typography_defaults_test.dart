import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_layout.dart';
import 'package:xxread/core/reader/reader_settings.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/reader_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('阅读页交付精校排版基线', () {
    expect(ReaderSettings.defaultFontSize, 19);
    expect(ReaderSettings.defaultLineHeight, 1.85);
    expect(ReaderSettings.defaultLetterSpacing, 0);
    expect(ReaderSettings.defaultFontWeight, 400);
    expect(ReaderSettings.defaultTextAlignment, ReaderTextAlignment.justified);
    expect(ReaderSettings.defaultHorizontalMargin, 22);
    expect(ReaderSettings.defaultFirstLineIndent, 2);
    expect(ReaderSettings.defaultParagraphSpacing, 0);
  });

  test('默认主题是纸黄，翻页/进度/标题页取精校值', () {
    expect(ReaderSettings.defaultThemeId, ReaderThemes.paper.id);
    expect(ReaderThemes.byId(ReaderSettings.defaultThemeId).id, 'paper');
    expect(ReaderSettings.defaultPageMode, ReaderPageMode.coverSlide);
    expect(
      ReaderSettings.defaultChapterProgressStyle,
      ReaderChapterProgressStyle.fraction,
    );
    expect(ReaderSettings.defaultChapterTitlePageEnabled, isFalse);
  });

  test('纸黄主题在主题顺序里排第一', () {
    expect(
      ReaderThemes.orderedPalettes.firstWhere((p) => p.id == 'paper').id,
      ReaderThemes.paper.id,
    );
    final concrete = ReaderThemes.all
        .where((palette) => palette.id != ReaderThemes.systemId)
        .toList(growable: false);
    expect(concrete.first.id, ReaderThemes.paper.id);
  });

  test('默认阅读字体是衬线宋体，字体面板含黑体与等宽', () {
    expect(FontCatalog.defaultReaderFont.id, FontCatalog.serifFont.id);
    expect(FontCatalog.serifFont.tone, FontTone.serif);
    final ids = FontCatalog.readerFonts
        .map((font) => font.id)
        .toList(growable: false);
    expect(ids, containsAll(<String>['system', 'serif', 'sans', 'mono']));
  });
}
