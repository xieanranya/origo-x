import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_header_footer_settings.dart';

void main() {
  test('defaults preserve the old fixed chrome', () {
    const settings = ReaderHeaderFooterSettings();
    expect(settings.showsHeader, isTrue);
    expect(settings.showsFooter, isTrue);
    expect(settings.headerHeight, 16);
    expect(settings.footerHeight, 12);
  });

  test('content toggles hide an empty bar', () {
    const settings = ReaderHeaderFooterSettings(
      headerShowChapter: false,
      headerShowBook: false,
      headerShowClock: false,
      headerShowBattery: false,
      footerShowChapterProgress: false,
      footerShowPage: false,
    );
    expect(settings.showsHeader, isFalse);
    expect(settings.showsFooter, isFalse);
    expect(settings.headerHeight, 0);
    expect(settings.footerHeight, 0);
  });

  test('json roundtrip', () {
    const original = ReaderHeaderFooterSettings(
      headerShowBook: true,
      headerPosition: ReaderChromePosition.center,
      headerFontSize: 14,
      footerShowPercent: true,
      footerPosition: ReaderChromePosition.right,
      footerFontSize: 12,
    );
    final restored = ReaderHeaderFooterSettings.fromJson(original.toJson());
    expect(restored, original);
  });

  test('partial or broken json falls back to defaults', () {
    const defaults = ReaderHeaderFooterSettings();
    final restored = ReaderHeaderFooterSettings.fromJson(
      <String, Object?>{'headerFontSize': 'bad', 'footerPosition': 42},
    );
    expect(restored.headerFontSize, defaults.headerFontSize);
    expect(restored.footerPosition, defaults.footerPosition);
  });

  test('font size is clamped', () {
    final settings = const ReaderHeaderFooterSettings().copyWith(
      headerFontSize: 99,
      footerFontSize: 1,
    );
    expect(settings.headerFontSize, ReaderHeaderFooterSettings.maxFontSize);
    expect(settings.footerFontSize, ReaderHeaderFooterSettings.minFontSize);
  });
}
