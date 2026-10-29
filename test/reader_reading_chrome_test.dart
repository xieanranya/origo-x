import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_control_chrome.dart';
import 'package:xxread/widgets/reader_reading_chrome.dart';

void main() {
  late int backTaps;
  late int bookmarkTaps;
  late int tocTaps;
  late int settingsTaps;
  late int previousChapterTaps;
  late int nextChapterTaps;
  late List<double> seeks;

  setUp(() {
    backTaps = 0;
    bookmarkTaps = 0;
    tocTaps = 0;
    settingsTaps = 0;
    previousChapterTaps = 0;
    nextChapterTaps = 0;
    seeks = <double>[];
  });

  Widget buildChrome({bool visible = true, double progress = 0.4}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          height: 844,
          child: Stack(
            children: [
              ReaderReadingChrome(
                palette: ReaderThemes.paper,
                visible: visible,
                bookTitle: '测试书名',
                chapterTitle: '第一章',
                pageProgress: progress,
                pageLabel: '5 / 25',
                bookmarked: true,
                readAloudActive: false,
                onBack: () => backTaps++,
                onBookmark: () => bookmarkTaps++,
                onPreviousChapter: () => previousChapterTaps++,
                onNextChapter: () => nextChapterTaps++,
                onPageProgressChanged: seeks.add,
                onTableOfContents: () => tocTaps++,
                onReadAloud: () {},
                onNightMode: () => settingsTaps++,
                onSettings: () => settingsTaps++,
                backTooltip: '返回',
                bookmarkTooltip: '书签',
                tableOfContentsTooltip: '目录',
                readAloudTooltip: '听书',
                settingsTooltip: '阅读设置',
                nightModeTooltip: '夜间',
                previousChapterTooltip: '上一章',
                nextChapterTooltip: '下一章',
                onMore: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('底部进度坞含滑杆、上一章/下一章和四个文字工具', (tester) async {
    await tester.pumpWidget(buildChrome());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reader-page-progress-slider')), findsOne);
    expect(
      find.byKey(const ValueKey('reader-previous-chapter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reader-next-chapter')), findsOneWidget);
    for (final key in <String>[
      'reader-tool-toc',
      'reader-tool-read-aloud',
      'reader-tool-night',
      'reader-tool-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('听书'), findsOneWidget);
    expect(find.text('夜间'), findsOneWidget);
    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('测试书名'), findsOneWidget);
  });

  testWidgets('不再渲染旧的 3 图标药丸底栏', (tester) async {
    await tester.pumpWidget(buildChrome());
    await tester.pumpAndSettle();

    expect(find.byType(ReaderControlIconButton), findsNothing);
    expect(find.byType(ReaderChromeOverlay), findsNothing);
    // 圆角 20 的矩形坞，而不是 999 药丸。
    final bars = tester.widgetList<ReaderControlBar>(
      find.byType(ReaderControlBar),
    );
    expect(bars, isNotEmpty);
    for (final bar in bars) {
      expect(bar.borderRadius, BorderRadius.circular(20));
    }
  });

  testWidgets('滑杆与章节按钮回调正确', (tester) async {
    await tester.pumpWidget(buildChrome());
    await tester.pumpAndSettle();

    tester
        .widget<Slider>(
          find.byKey(const ValueKey('reader-page-progress-slider')),
        )
        .onChanged!(0.75);
    await tester.pump();
    expect(seeks, <double>[0.75]);

    await tester.tap(find.byKey(const ValueKey('reader-previous-chapter')));
    await tester.tap(find.byKey(const ValueKey('reader-next-chapter')));
    await tester.pump();
    expect(previousChapterTaps, 1);
    expect(nextChapterTaps, 1);

    await tester.tap(find.byKey(const ValueKey('reader-tool-toc')));
    await tester.pump();
    expect(tocTaps, 1);

    await tester.tap(find.byKey(const ValueKey('reader-back')));
    await tester.pump();
    expect(backTaps, 1);
  });

  testWidgets('隐藏时顶栏与底栏移出屏幕且不可点', (tester) async {
    await tester.pumpWidget(buildChrome(visible: false));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reader-tool-settings')).hitTestable(),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('reader-tool-settings')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(settingsTaps, 0);
  });
}
