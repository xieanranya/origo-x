import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_settings.dart';

void main() {
  test('reader ships a calibrated default typography', () {
    expect(ReaderSettings.defaultFontSize, 19);
    expect(ReaderSettings.defaultLineHeight, 1.85);
    expect(ReaderSettings.defaultLetterSpacing, 0);
    expect(ReaderSettings.defaultTextAlignment, ReaderTextAlignment.justified);
    expect(ReaderSettings.defaultHorizontalMargin, 22);
    expect(ReaderSettings.defaultFirstLineIndent, 2);
    expect(ReaderSettings.defaultParagraphSpacing, 0);
  });
}
