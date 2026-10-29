import 'package:flutter/material.dart';

import '../core/reader/reader_header_footer_settings.dart';
import '../core/reader/reader_settings.dart';
import '../utils/localization_extension.dart';

String formatReaderChapterProgress(
  BuildContext context, {
  required ReaderChapterProgressStyle style,
  required int chapterIndex,
  required int chapterCount,
}) {
  if (chapterCount <= 0 || chapterIndex < 0 || chapterIndex >= chapterCount) {
    return '';
  }
  return switch (style) {
    ReaderChapterProgressStyle.hidden => '',
    ReaderChapterProgressStyle.fraction =>
      context.l10n.readerChapterProgressFraction(
        chapterIndex + 1,
        chapterCount,
      ),
    ReaderChapterProgressStyle.remaining =>
      context.l10n.readerChapterProgressRemaining(
        chapterCount - chapterIndex - 1,
      ),
  };
}

/// Shares one footer row between paper leaves and the scrolling viewport.
///
/// 固定「章节进度 + 页码」，上下滚动模式的页脚仍在用它。
class ReaderProgressFooter extends StatelessWidget {
  const ReaderProgressFooter({
    super.key,
    required this.chapterLabel,
    required this.pageLabel,
    this.pageKey,
    this.style,
    this.pageOnLeft = false,
  });

  final String chapterLabel;
  final String pageLabel;
  final Key? pageKey;
  final TextStyle? style;
  final bool pageOnLeft;

  @override
  Widget build(BuildContext context) {
    final page = Text(pageLabel, key: pageKey, style: style, maxLines: 1);
    final chapter = Expanded(
      child: Text(
        chapterLabel,
        style: style,
        textAlign: pageOnLeft ? TextAlign.right : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Row(
      textDirection: TextDirection.ltr,
      children: pageOnLeft
          ? [page, const SizedBox(width: 12), chapter]
          : [chapter, const SizedBox(width: 12), page],
    );
  }
}

/// 可配置页脚：章节进度 / 页码 / 百分比 / 剩余页数，按 [settings] 组合与对齐。
class ReaderPageFooter extends StatelessWidget {
  const ReaderPageFooter({
    super.key,
    required this.chapterLabel,
    required this.pageLabel,
    required this.percentLabel,
    required this.remainingLabel,
    required this.settings,
    required this.style,
    this.pageOnLeft = false,
    this.forceSplit = false,
    this.pageKey,
  });

  final String chapterLabel;
  final String pageLabel;
  final String percentLabel;
  final String remainingLabel;
  final ReaderHeaderFooterSettings settings;
  final TextStyle style;

  /// 双页模式左页：页码在左、章节进度在右。
  final bool pageOnLeft;

  /// 双页模式强制「分散」，忽略用户选的对齐方式。
  final bool forceSplit;

  final Key? pageKey;

  @override
  Widget build(BuildContext context) {
    final chapterText = settings.footerShowChapterProgress ? chapterLabel : '';
    final pageParts = <String>[
      if (settings.footerShowPage) pageLabel,
      if (settings.footerShowPercent) percentLabel,
      if (settings.footerShowRemaining) remainingLabel,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    final pageText = pageParts.join(' · ');
    final allText = [
      if (chapterText.isNotEmpty) chapterText,
      if (pageText.isNotEmpty) pageText,
    ].join(' · ');
    if (allText.isEmpty) return const SizedBox.shrink();
    final position = forceSplit
        ? ReaderChromePosition.split
        : settings.footerPosition;

    if (pageOnLeft) {
      return Row(
        children: [
          Flexible(
            child: Text(
              pageText,
              key: pageKey,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapterText,
              textAlign: TextAlign.right,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return switch (position) {
      ReaderChromePosition.split => Row(
        children: [
          Expanded(
            child: Text(
              chapterText,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              pageText,
              key: pageKey,
              textAlign: TextAlign.right,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      ReaderChromePosition.left => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          allText,
          key: pageKey,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      ReaderChromePosition.center => Align(
        alignment: Alignment.center,
        child: Text(
          allText,
          key: pageKey,
          textAlign: TextAlign.center,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      ReaderChromePosition.right => Align(
        alignment: Alignment.centerRight,
        child: Text(
          allText,
          key: pageKey,
          textAlign: TextAlign.right,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    };
  }
}
