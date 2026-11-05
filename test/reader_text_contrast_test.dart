// 文件说明：正文取色的对比度兜底回归测试。
// 「文字亮度」在浅色主题下是反向语义（0 = 纯白字），拉到极端会让正文
// 融进纸面。这里锁住两端的安全边界，避免以后又被改回去。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_settings.dart';

void main() {
  group('正文取色', () {
    test('浅色主题：默认值 100 是纯黑，最清楚', () {
      expect(
        readerTextColorForBrightness(100, isDarkMode: false),
        const Color(0xFF000000),
      );
    });

    test('浅色主题：拉到 0 也只淡到 #AAAAAA，不会变成白字', () {
      final lightest = readerTextColorForBrightness(0, isDarkMode: false);
      expect(lightest.r, closeTo(170 / 255, 0.01));
      expect(lightest.g, closeTo(170 / 255, 0.01));
      expect(lightest.b, closeTo(170 / 255, 0.01));
    });

    test('浅色主题：极端低值（5）同样被兜住', () {
      expect(
        readerTextColorForBrightness(5, isDarkMode: false),
        readerTextColorForBrightness(0, isDarkMode: false),
      );
    });

    test('深色主题：默认值 100 是纯白', () {
      expect(
        readerTextColorForBrightness(100, isDarkMode: true),
        const Color(0xFFFFFFFF),
      );
    });

    test('深色主题：拉到 0 只暗到 #5A5A5A，不会黑成一片', () {
      final darkest = readerTextColorForBrightness(0, isDarkMode: true);
      expect(darkest.r, closeTo(90 / 255, 0.01));
    });
  });
}
