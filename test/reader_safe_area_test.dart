import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';

void main() {
  test('default reserves match the old layout', () {
    const metrics = ReaderSafeAreaMetrics(
      viewPadding: EdgeInsets.only(top: 24, bottom: 16),
      topMargin: 4,
      bottomMargin: 0,
      topChromeReserve: 24,
    );
    expect(metrics.contentTop, 52);
    expect(metrics.contentBottom, 24);
  });

  test('footer off reclaims the footer reserve', () {
    const metrics = ReaderSafeAreaMetrics(
      viewPadding: EdgeInsets.only(top: 24, bottom: 16),
      topMargin: 4,
      bottomMargin: 0,
      topChromeReserve: 24,
      showFooter: false,
    );
    expect(metrics.contentBottom, 16);
  });

  test('larger header and footer grow the reserved area', () {
    const metrics = ReaderSafeAreaMetrics(
      viewPadding: EdgeInsets.only(top: 24, bottom: 16),
      topMargin: 4,
      bottomMargin: 0,
      topChromeReserve: 27.2,
      headerHeight: 19.2,
      footerHeight: 19.2,
    );
    expect(metrics.contentTop, closeTo(55.2, 0.001));
    expect(metrics.contentBottom, closeTo(31.2, 0.001));
  });
}
