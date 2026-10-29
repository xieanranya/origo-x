import 'package:flutter/material.dart';

import '../core/reader/reader_header_footer_settings.dart';
import '../core/reader/reader_leaf_status.dart';
import '../core/reader/reader_safe_area.dart';
import '../utils/reader_themes.dart';
import 'reader_theme_background.dart';
import 'reader_progress_footer.dart';
import 'reader_top_information_bar.dart';

enum ReaderPageNumberPlacement { bottomLeft, bottomRight }

@immutable
class ReaderPageSnapshotKey {
  const ReaderPageSnapshotKey({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;

  @override
  bool operator ==(Object other) =>
      other is ReaderPageSnapshotKey &&
      other.pageIdentity == pageIdentity &&
      other.layoutFingerprint == layoutFingerprint &&
      other.themeId == themeId;

  @override
  int get hashCode => Object.hash(pageIdentity, layoutFingerprint, themeId);

  @override
  String toString() => '$pageIdentity@$layoutFingerprint#$themeId';
}

@immutable
class ReaderPaperPageMetadata {
  const ReaderPaperPageMetadata({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
    required this.chapterTitle,
    required this.pageNumber,
    required this.pageCount,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;
  final String chapterTitle;
  final int pageNumber;
  final int pageCount;

  ReaderPageSnapshotKey get snapshotKey => ReaderPageSnapshotKey(
    pageIdentity: pageIdentity,
    layoutFingerprint: layoutFingerprint,
    themeId: themeId,
  );

  String get pageLabel => '$pageNumber / $pageCount';
}

/// A complete sheet of reader paper: body and quiet editorial footer.
///
/// The footer is deliberately inside the leaf so PageView and classic fold
/// move the same pixels. Floating reader controls remain a
/// separate HUD.
class ReaderPaperPageLeaf extends StatelessWidget {
  const ReaderPaperPageLeaf({
    super.key,
    required this.palette,
    required this.safeArea,
    required this.metadata,
    required this.child,
    this.chapterProgressLabel = '',
    this.pageNumberPlacement = ReaderPageNumberPlacement.bottomRight,
    this.horizontalPadding = 14,
    this.pageNumberHorizontalPadding = 24,
    this.showTopInformation = false,
    this.showFloatingStatus = false,
    this.floatingStatusHorizontalPadding = 32,
    this.topInformationLayout = ReaderTopInformationLayout.full,
    this.showPageNumber = true,
    this.status,
    this.headerFooter = const ReaderHeaderFooterSettings(),
    this.bookTitle = '',
    this.percentLabel = '',
    this.remainingLabel = '',
  });

  final ReaderThemePalette palette;
  final ReaderSafeAreaMetrics safeArea;
  final ReaderPaperPageMetadata metadata;
  final Widget child;
  final String chapterProgressLabel;
  final ReaderPageNumberPlacement pageNumberPlacement;
  final double horizontalPadding;
  final double pageNumberHorizontalPadding;
  final bool showTopInformation;
  final bool showFloatingStatus;
  final double floatingStatusHorizontalPadding;
  final ReaderTopInformationLayout topInformationLayout;
  final bool showPageNumber;
  final ReaderLeafStatusData? status;

  /// 页眉 / 页脚配置：控制显示哪些内容、对齐与字号。
  final ReaderHeaderFooterSettings headerFooter;

  /// 书名（页眉勾选「书名」时显示）。
  final String bookTitle;

  /// 页脚百分比文案，例如 `50%`。
  final String percentLabel;

  /// 页脚剩余页数文案。
  final String remainingLabel;

  @override
  Widget build(BuildContext context) {
    final footerStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: headerFooter.footerFontSize,
          height: 1,
          letterSpacing: 0.08,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: headerFooter.footerFontSize,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final showHeader = showTopInformation && headerFooter.showsHeader;
    final showFooter = showPageNumber && headerFooter.showsFooter;
    final semanticsLabel = showFooter
        ? metadata.chapterTitle.isEmpty
              ? metadata.pageLabel
              : '${metadata.chapterTitle}, ${metadata.pageLabel}'
        : metadata.chapterTitle;

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ReaderThemeBackground(
        palette: palette,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (showHeader)
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                top: safeArea.readerTopBarTop,
                height: safeArea.headerHeight,
                child: ReaderTopInformationBar(
                  key: ValueKey(
                    'reader-leaf-top-information:${metadata.pageIdentity}',
                  ),
                  palette: palette,
                  title: metadata.chapterTitle,
                  bookTitle: bookTitle,
                  status: status,
                  layout: topInformationLayout,
                  settings: headerFooter,
                  height: safeArea.headerHeight,
                ),
              ),
            if (showFloatingStatus)
              Positioned(
                left: floatingStatusHorizontalPadding,
                right: floatingStatusHorizontalPadding,
                top: 0,
                height: safeArea.floatingStatusHeight,
                child: ReaderFloatingStatusBar(
                  key: ValueKey(
                    'reader-leaf-floating-status:${metadata.pageIdentity}',
                  ),
                  palette: palette,
                  status: status,
                  layout: topInformationLayout,
                ),
              ),
            if (showFooter)
              Positioned(
                left: pageNumberHorizontalPadding,
                right: pageNumberHorizontalPadding,
                bottom: safeArea.pageNumberBottom,
                height: safeArea.footerHeight,
                child: ReaderPageFooter(
                  key: ValueKey('reader-leaf-footer:${metadata.pageIdentity}'),
                  chapterLabel: chapterProgressLabel,
                  pageLabel: metadata.pageLabel,
                  percentLabel: percentLabel,
                  remainingLabel: remainingLabel,
                  settings: headerFooter,
                  forceSplit:
                      topInformationLayout != ReaderTopInformationLayout.full,
                  pageKey: ValueKey(
                    'reader-leaf-page:${metadata.pageIdentity}',
                  ),
                  pageOnLeft:
                      pageNumberPlacement ==
                      ReaderPageNumberPlacement.bottomLeft,
                  style: footerStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
