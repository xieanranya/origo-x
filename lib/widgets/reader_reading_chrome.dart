import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/reader/reader_auto_page_turn_controller.dart';
import '../core/reader/reader_leaf_status.dart';
import '../utils/glass_config.dart';
import '../utils/reader_themes.dart';
import 'reader_control_chrome.dart';
import 'reader_thin_slider.dart';
import 'reader_top_information_bar.dart';

/// 阅读页正片使用的新 Chrome（对齐 `hybrid.html` C 版）。
///
/// 顶部：返回 / 书名 / 书签 / 更多；底部：上一章 · 细滑杆 · 百分比 · 下一章，
/// 下面是目录 / 听书 / 夜间 / 设置四个带文字标签的工具。
/// 面板是 flat 半透明纸面（blur 18 + 1px 细边），不使用旧的玻璃渐变药丸。
class ReaderReadingChrome extends StatelessWidget {
  const ReaderReadingChrome({
    super.key,
    required this.palette,
    required this.visible,
    required this.bookTitle,
    required this.chapterTitle,
    required this.pageProgress,
    required this.pageLabel,
    required this.bookmarked,
    required this.readAloudActive,
    required this.onBack,
    required this.onBookmark,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onPageProgressChanged,
    required this.onTableOfContents,
    required this.onReadAloud,
    required this.onNightMode,
    required this.onSettings,
    this.onMore,
    this.bookmarkBusy = false,
    this.backTooltip = '',
    this.bookmarkTooltip = '',
    this.tableOfContentsTooltip = '',
    this.readAloudTooltip,
    this.settingsTooltip = '',
    this.nightModeTooltip = '夜间',
    this.moreTooltip = '更多',
    this.previousChapterTooltip = '上一章',
    this.nextChapterTooltip = '下一章',
    this.topKey,
    this.bottomKey,
    this.autoPageTurnController,
    this.onResumeAutoPageTurn,
    this.onLocateReadAloud,
    this.showViewportStatus = false,
    this.showViewportTitle = false,
    this.viewportTitleTop = 0,
    this.viewportTitleKey,
    this.readerStatus,
    this.statusBottom = 0,
    this.statusBuilder,
    this.viewportStatusHorizontalPadding = 14,
  });

  final ReaderThemePalette palette;
  final bool visible;
  final String bookTitle;
  final String chapterTitle;

  /// 本章内进度 0..1。
  final double pageProgress;

  /// 例如 `5 / 25`。
  final String pageLabel;
  final bool bookmarked;
  final bool readAloudActive;
  final VoidCallback onBack;
  final VoidCallback? onBookmark;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onPageProgressChanged;
  final VoidCallback? onTableOfContents;
  final VoidCallback? onReadAloud;
  final VoidCallback onNightMode;
  final VoidCallback onSettings;
  final VoidCallback? onMore;
  final bool bookmarkBusy;
  final String backTooltip;
  final String bookmarkTooltip;
  final String tableOfContentsTooltip;
  final String? readAloudTooltip;
  final String settingsTooltip;
  final String nightModeTooltip;
  final String moreTooltip;
  final String previousChapterTooltip;
  final String nextChapterTooltip;
  final Key? topKey;
  final Key? bottomKey;

  // ---- 原 Chrome 里挂着的辅助层，换 UI 不能丢 ----
  final ReaderAutoPageTurnController? autoPageTurnController;
  final VoidCallback? onResumeAutoPageTurn;
  final VoidCallback? onLocateReadAloud;
  final bool showViewportStatus;
  final bool showViewportTitle;
  final double viewportTitleTop;
  final Key? viewportTitleKey;
  final ReaderLeafStatusData? readerStatus;
  final double statusBottom;
  final ReaderStatusBuilder? statusBuilder;
  final double viewportStatusHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final chromeDuration = reducedMotion
        ? Duration.zero
        : Duration(milliseconds: visible ? 300 : 420);
    final progress = pageProgress.clamp(0.0, 1.0).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showViewportTitle)
          Positioned(
            left: 30,
            right: 30,
            top: viewportTitleTop,
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: viewportTitleKey,
                opacity: visible ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: ReaderTopInformationBar(
                  palette: palette,
                  title: chapterTitle.isEmpty ? bookTitle : chapterTitle,
                  status: readerStatus,
                ),
              ),
            ),
          ),
        if (showViewportStatus && statusBuilder != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: statusBottom,
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: viewportStatusHorizontalPadding,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: statusBuilder!(
                    context,
                    textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1,
                      color: palette.secondaryText.withValues(
                        alpha: visible ? 0 : 0.58,
                      ),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    null,
                  ),
                ),
              ),
            ),
          ),
        AnimatedPositioned(
          key: topKey,
          duration: chromeDuration,
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          top: visible ? 10 : -120,
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: SafeArea(
                bottom: false,
                child: _ReaderGlassPanel(
                  palette: palette,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          _ReaderChromeIconButton(
                            buttonKey: const ValueKey('reader-back'),
                            palette: palette,
                            onPressed: onBack,
                            tooltip: backTooltip,
                            icon: Icons.arrow_back_rounded,
                          ),
                          Expanded(
                            child: Text(
                              bookTitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                inherit: false,
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: palette.text,
                              ),
                            ),
                          ),
                          _ReaderChromeIconButton(
                            palette: palette,
                            onPressed: bookmarkBusy ? null : onBookmark,
                            tooltip: bookmarkTooltip,
                            icon: bookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                          if (onMore != null)
                            _ReaderChromeIconButton(
                              palette: palette,
                              onPressed: onMore,
                              tooltip: moreTooltip,
                              icon: Icons.more_horiz_rounded,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          key: bottomKey,
          duration: chromeDuration,
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          bottom: visible ? 16 : -220,
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: SafeArea(
                top: false,
                child: _ReaderGlassPanel(
                  palette: palette,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 1, 2, 8),
                          child: Row(
                            children: [
                              _ReaderChapterNavButton(
                                buttonKey: const ValueKey(
                                  'reader-previous-chapter',
                                ),
                                palette: palette,
                                label: previousChapterTooltip,
                                onTap: onPreviousChapter,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ReaderThinSlider(
                                  key: const ValueKey(
                                    'reader-page-progress-slider',
                                  ),
                                  value: progress,
                                  onChanged: onPageProgressChanged,
                                  activeColor: palette.accent,
                                  inactiveColor: palette.controlBar,
                                  thumbFill: palette.surface,
                                  thumbBorder: palette.accent,
                                  semanticLabel: pageLabel,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '${(progress * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: TextStyle(
                                    inherit: false,
                                    fontSize: 10,
                                    height: 1,
                                    color: palette.secondaryText,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _ReaderChapterNavButton(
                                buttonKey: const ValueKey(
                                  'reader-next-chapter',
                                ),
                                palette: palette,
                                label: nextChapterTooltip,
                                onTap: onNextChapter,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          color: palette.text.withValues(alpha: 0.09),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              _ReaderDockTool(
                                toolKey: const ValueKey('reader-tool-toc'),
                                palette: palette,
                                icon: Icons.format_list_bulleted_rounded,
                                label: tableOfContentsTooltip,
                                tooltip: tableOfContentsTooltip,
                                onTap: onTableOfContents,
                              ),
                              _ReaderDockTool(
                                toolKey: const ValueKey(
                                  'reader-tool-read-aloud',
                                ),
                                palette: palette,
                                icon: readAloudActive
                                    ? Icons.graphic_eq_rounded
                                    : Icons.headphones_rounded,
                                label: readAloudTooltip ?? '听书',
                                tooltip: readAloudTooltip ?? '',
                                active: readAloudActive,
                                onTap: onReadAloud,
                              ),
                              _ReaderDockTool(
                                toolKey: const ValueKey('reader-tool-night'),
                                palette: palette,
                                icon: Icons.dark_mode_rounded,
                                label: nightModeTooltip,
                                tooltip: nightModeTooltip,
                                onTap: onNightMode,
                              ),
                              _ReaderDockTool(
                                toolKey: const ValueKey('reader-tool-settings'),
                                palette: palette,
                                icon: Icons.tune_rounded,
                                label: settingsTooltip,
                                tooltip: settingsTooltip,
                                onTap: onSettings,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onLocateReadAloud != null)
          AnimatedPositioned(
            key: const ValueKey('reader-aloud-locate-slide'),
            duration: reducedMotion
                ? Duration.zero
                : Duration(
                    milliseconds: visible && readAloudActive ? 300 : 420,
                  ),
            curve: Curves.easeOutCubic,
            right: visible && readAloudActive
                ? 8 + MediaQuery.paddingOf(context).right
                : -72,
            top: MediaQuery.sizeOf(context).height * 0.56 - 56,
            child: IgnorePointer(
              ignoring: !visible || !readAloudActive,
              child: ExcludeSemantics(
                excluding: !visible || !readAloudActive,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.controlBar.withValues(alpha: 0.8),
                    border: Border.all(
                      color: palette.text.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    key: const ValueKey('reader-aloud-locate'),
                    tooltip: readAloudTooltip ?? '',
                    onPressed: onLocateReadAloud,
                    color: palette.text,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 22),
                  ),
                ),
              ),
            ),
          ),
        if (autoPageTurnController != null)
          ReaderAutoPageTurnControl(
            palette: palette,
            controller: autoPageTurnController!,
            chromeVisible: visible,
            onResume: onResumeAutoPageTurn,
          ),
        if (autoPageTurnController != null)
          AnimatedBuilder(
            animation: autoPageTurnController!,
            builder: (context, _) {
              final shown = visible && autoPageTurnController!.shortcutVisible;
              return AnimatedPositioned(
                key: const ValueKey('reader-auto-page-turn-shortcut-slide'),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Duration(milliseconds: shown ? 300 : 420),
                curve: Curves.easeOutCubic,
                right: shown ? 8 + MediaQuery.paddingOf(context).right : -72,
                top: MediaQuery.sizeOf(context).height * 0.56,
                child: IgnorePointer(
                  ignoring: !shown,
                  child: ExcludeSemantics(
                    excluding: !shown,
                    child: ReaderAutoPageTurnShortcut(
                      palette: palette,
                      controller: autoPageTurnController!,
                      onResume: onResumeAutoPageTurn,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// flat 半透明纸面：1px 细边 + blur(18) + 20 圆角 + 柔和投影。
class _ReaderGlassPanel extends StatelessWidget {
  const _ReaderGlassPanel({required this.palette, required this.child});

  final ReaderThemePalette palette;
  final Widget child;

  static final BorderRadius _radius = BorderRadius.circular(20);

  @override
  Widget build(BuildContext context) {
    final blurEnabled = !GlassEffectConfig.shouldDisableBlur;
    final surface = blurEnabled
        ? palette.surface.withValues(alpha: 0.78)
        : palette.surface;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: _radius,
        border: Border.all(color: palette.text.withValues(alpha: 0.09)),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.brightness == Brightness.dark ? 0.38 : 0.15,
            ),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: blurEnabled
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: panel,
              )
            : panel,
      ),
    );
  }
}

class _ReaderChromeIconButton extends StatelessWidget {
  const _ReaderChromeIconButton({
    this.buttonKey,
    required this.palette,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
  });

  final Key? buttonKey;
  final ReaderThemePalette palette;
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? palette.secondaryText.withValues(alpha: 0.5)
                : palette.text,
          ),
        ),
      ),
    );
  }
}

class _ReaderChapterNavButton extends StatelessWidget {
  const _ReaderChapterNavButton({
    this.buttonKey,
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Key? buttonKey;
  final ReaderThemePalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              inherit: false,
              fontSize: 10.5,
              height: 1.2,
              color: palette.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderDockTool extends StatelessWidget {
  const _ReaderDockTool({
    required this.toolKey,
    required this.palette,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final Key toolKey;
  final ReaderThemePalette palette;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? palette.accent
        : onTap == null
        ? palette.secondaryText.withValues(alpha: 0.5)
        : palette.secondaryText;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            key: toolKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 19, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      inherit: false,
                      fontSize: 9.5,
                      height: 1.1,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
