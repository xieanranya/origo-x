import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_header_footer_settings.dart';
import 'package:xxread/core/reader/reader_safe_area.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_paper_page_leaf.dart';

void main() {
  ReaderPaperPageLeaf buildLeaf(
    ReaderHeaderFooterSettings settings,
    ReaderSafeAreaMetrics safeArea,
  ) {
    return ReaderPaperPageLeaf(
      palette: ReaderThemes.day,
      safeArea: safeArea,
      metadata: const ReaderPaperPageMetadata(
        pageIdentity: 'test',
        layoutFingerprint: 'fingerprint',
        themeId: 'day',
        chapterTitle: 'Chapter',
        pageNumber: 1,
        pageCount: 2,
      ),
      chapterProgressLabel: '1/10 chapters',
      bookTitle: 'Book',
      percentLabel: '50%',
      remainingLabel: '1 page left',
      headerFooter: settings,
      showTopInformation: true,
      child: const SizedBox.expand(),
    );
  }

  testWidgets('header and footer render selected content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLeaf(
            const ReaderHeaderFooterSettings(
              headerShowBook: true,
              footerShowPercent: true,
              footerShowRemaining: true,
            ),
            const ReaderSafeAreaMetrics(
              viewPadding: EdgeInsets.zero,
              topMargin: 0,
              bottomMargin: 0,
              topChromeReserve: 24,
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Chapter'), findsWidgets);
    expect(find.textContaining('Book'), findsWidgets);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.textContaining('1 page left'), findsOneWidget);
  });

  testWidgets('disabled header and footer disappear', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLeaf(
            const ReaderHeaderFooterSettings(
              headerEnabled: false,
              footerEnabled: false,
            ),
            const ReaderSafeAreaMetrics(
              viewPadding: EdgeInsets.zero,
              topMargin: 0,
              bottomMargin: 0,
              topChromeReserve: 24,
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Book'), findsNothing);
    expect(find.textContaining('50%'), findsNothing);
  });

  testWidgets('footer follows the footer height from settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLeaf(
            const ReaderHeaderFooterSettings(),
            const ReaderSafeAreaMetrics(
              viewPadding: EdgeInsets.zero,
              topMargin: 0,
              bottomMargin: 0,
              topChromeReserve: 24,
              footerHeight: 19.2,
            ),
          ),
        ),
      ),
    );
    final footerBox = tester.getSize(
      find.byKey(const ValueKey('reader-leaf-footer:test')),
    );
    expect(footerBox.height, 19.2);
  });
}
