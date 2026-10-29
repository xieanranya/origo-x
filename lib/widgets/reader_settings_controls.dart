import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/reader/reader_layout.dart';
import '../core/reader/reader_auto_page_turn_controller.dart';
import '../core/reader/reader_margin_settings.dart';
import '../core/reader/reader_header_footer_settings.dart';
import '../core/reader/reader_settings.dart';
import '../core/reader/reader_custom_theme.dart';
import '../core/reader/reader_system_ui.dart';
import '../utils/reader_themes.dart';
import '../utils/localization_extension.dart';
import 'reader_theme_background.dart';
import 'reader_chapter_progress_setting_tile.dart';

@immutable
class ReaderFontChoice {
  const ReaderFontChoice({
    required this.valueLabel,
    required this.hint,
    required this.family,
    required this.fallbackFamilies,
    required this.supportsVariableWeight,
    required this.fontWeightHint,
    this.variableWeightMin,
    this.variableWeightMax,
  });

  final String valueLabel;
  final String hint;
  final String? family;
  final List<String> fallbackFamilies;
  final bool supportsVariableWeight;
  final String fontWeightHint;
  final int? variableWeightMin;
  final int? variableWeightMax;
}

/// 页眉页脚 Tab 的文案集合（避免二十多个字符串参数）。
@immutable
class ReaderHeaderFooterLabels {
  const ReaderHeaderFooterLabels({
    required this.tabLabel,
    required this.headerSectionTitle,
    required this.headerEnabledTitle,
    required this.headerEnabledHint,
    required this.headerChapterContent,
    required this.headerBookContent,
    required this.headerTimeContent,
    required this.headerBatteryContent,
    required this.headerPositionLabel,
    required this.headerFontSizeLabel,
    required this.headerTopBarHint,
    required this.footerSectionTitle,
    required this.footerEnabledTitle,
    required this.footerEnabledHint,
    required this.footerChapterContent,
    required this.footerPageContent,
    required this.footerPercentContent,
    required this.footerRemainingContent,
    required this.footerPositionLabel,
    required this.footerFontSizeLabel,
    required this.positionSplit,
    required this.positionLeft,
    required this.positionCenter,
    required this.positionRight,
  });

  final String tabLabel;
  final String headerSectionTitle;
  final String headerEnabledTitle;
  final String headerEnabledHint;
  final String headerChapterContent;
  final String headerBookContent;
  final String headerTimeContent;
  final String headerBatteryContent;
  final String headerPositionLabel;
  final String headerFontSizeLabel;
  final String headerTopBarHint;
  final String footerSectionTitle;
  final String footerEnabledTitle;
  final String footerEnabledHint;
  final String footerChapterContent;
  final String footerPageContent;
  final String footerPercentContent;
  final String footerRemainingContent;
  final String footerPositionLabel;
  final String footerFontSizeLabel;
  final String positionSplit;
  final String positionLeft;
  final String positionCenter;
  final String positionRight;
}

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.title,
    required this.tabThemeLabel,
    required this.tabTextLabel,
    required this.tabLayoutLabel,
    required this.advancedTypographyTitle,
    required this.themeDescription,
    required this.pageModeTitle,
    required this.pageModeSummary,
    required this.topBarStyleTitle,
    required this.topBarStyleSummary,
    this.chapterProgressStyle = ReaderChapterProgressStyle.hidden,
    this.onChapterProgressStyleChanged,
    required this.pullBookmarkTitle,
    required this.pullBookmarkHint,
    required this.tapPageAnimationTitle,
    required this.tapPageAnimationHint,
    required this.tapZonesTitle,
    required this.tapZonesHint,
    required this.showTabletTwoPageToggle,
    required this.tabletTwoPageTitle,
    required this.tabletTwoPageHint,
    required this.fontFamilyLabel,
    required this.fontFamilyValueLabel,
    required this.fontFamilyHint,
    required this.onFontFamilyTap,
    this.onRestoreDesignDefaults,
    required this.fontSizeLabel,
    required this.textBrightnessLabel,
    required this.dimTextInDarkModeTitle,
    required this.dimTextInDarkModeHint,
    required this.fontWeightLabel,
    required this.fontWeightValueLabels,
    required this.fontWeightHint,
    required this.fontWeightPreviewText,
    required this.lineHeightLabel,
    required this.letterSpacingLabel,
    required this.textAlignmentLabel,
    required this.textAlignmentNaturalLabel,
    required this.textAlignmentJustifiedLabel,
    required this.firstLineIndentLabel,
    required this.paragraphSpacingLabel,
    required this.horizontalMarginLabel,
    required this.topMarginLabel,
    required this.bottomMarginLabel,
    required this.chapterTitlePageTitle,
    required this.chapterTitlePageHint,
    this.showChapterTitlePageToggle = true,
    required this.themeId,
    required this.fontSize,
    required this.textBrightness,
    required this.dimTextInDarkMode,
    required this.fontWeight,
    this.fontFamily,
    this.fontFamilyFallback = const <String>[],
    this.fontWeightSupportsVariable = false,
    this.fontWeightVariableMin,
    this.fontWeightVariableMax,
    required this.lineHeight,
    required this.letterSpacing,
    required this.textAlignment,
    required this.firstLineIndent,
    required this.paragraphSpacing,
    required this.horizontalMargin,
    required this.topMargin,
    required this.bottomMargin,
    required this.pullBookmarkEnabled,
    required this.tapPageAnimationEnabled,
    required this.tabletTwoPageEnabled,
    required this.chapterTitlePageEnabled,
    required this.themeLabelFor,
    required this.onThemeChanged,
    required this.onCustomThemeTap,
    this.onThemeConfigChanged,
    required this.onPageModeTap,
    this.autoPageTurnController,
    this.autoPageTurnIsVertical = false,
    this.onAutoPageTurnSettings,
    required this.onTopBarStyleTap,
    required this.onTapZonesTap,
    required this.onFontSizeChanged,
    required this.onTextBrightnessChanged,
    required this.onDimTextInDarkModeChanged,
    required this.onFontWeightChanged,
    required this.onLineHeightChanged,
    required this.onLetterSpacingChanged,
    required this.onTextAlignmentChanged,
    required this.onFirstLineIndentChanged,
    required this.onParagraphSpacingChanged,
    required this.onHorizontalMarginChanged,
    required this.onTopMarginChanged,
    required this.onBottomMarginChanged,
    required this.onPullBookmarkChanged,
    required this.onTapPageAnimationChanged,
    required this.onTabletTwoPageChanged,
    required this.onChapterTitlePageChanged,
    required this.headerFooter,
    required this.headerFooterLabels,
    required this.onHeaderFooterChanged,
    this.headerFooterHint,
    this.doneLabel,
  });

  final String title;
  final String tabThemeLabel;
  final String tabTextLabel;
  final String tabLayoutLabel;
  final String advancedTypographyTitle;
  final String themeDescription;
  final String pageModeTitle;
  final String pageModeSummary;
  final String topBarStyleTitle;
  final String topBarStyleSummary;
  final ReaderChapterProgressStyle chapterProgressStyle;
  final ValueChanged<ReaderChapterProgressStyle>? onChapterProgressStyleChanged;
  final String pullBookmarkTitle;
  final String pullBookmarkHint;
  final String tapPageAnimationTitle;
  final String tapPageAnimationHint;
  final String tapZonesTitle;
  final String tapZonesHint;
  final bool showTabletTwoPageToggle;
  final String tabletTwoPageTitle;
  final String tabletTwoPageHint;
  final String fontFamilyLabel;
  final String fontFamilyValueLabel;
  final String fontFamilyHint;
  final Future<ReaderFontChoice?> Function() onFontFamilyTap;

  /// 「恢复精校默认」：写回精校默认值并刷新阅读页，不清书籍进度/书签。
  final Future<void> Function()? onRestoreDesignDefaults;
  final String fontSizeLabel;
  final String textBrightnessLabel;
  final String dimTextInDarkModeTitle;
  final String dimTextInDarkModeHint;
  final String fontWeightLabel;
  final List<String> fontWeightValueLabels;
  final String fontWeightHint;
  final String fontWeightPreviewText;
  final String lineHeightLabel;
  final String letterSpacingLabel;
  final String textAlignmentLabel;
  final String textAlignmentNaturalLabel;
  final String textAlignmentJustifiedLabel;
  final String firstLineIndentLabel;
  final String paragraphSpacingLabel;
  final String horizontalMarginLabel;
  final String topMarginLabel;
  final String bottomMarginLabel;
  final String chapterTitlePageTitle;
  final String chapterTitlePageHint;
  final bool showChapterTitlePageToggle;
  final String themeId;
  final double fontSize;
  final int textBrightness;
  final bool dimTextInDarkMode;
  final int fontWeight;
  final String? fontFamily;
  final List<String> fontFamilyFallback;
  final bool fontWeightSupportsVariable;
  final int? fontWeightVariableMin;
  final int? fontWeightVariableMax;
  final double lineHeight;
  final double letterSpacing;
  final ReaderTextAlignment textAlignment;
  final int firstLineIndent;
  final int paragraphSpacing;
  final double horizontalMargin;
  final double topMargin;
  final double bottomMargin;
  final bool pullBookmarkEnabled;
  final bool tapPageAnimationEnabled;
  final bool tabletTwoPageEnabled;
  final bool chapterTitlePageEnabled;
  final String Function(String themeId) themeLabelFor;
  final ValueChanged<String> onThemeChanged;
  final VoidCallback onCustomThemeTap;

  /// 「跟随系统」的日夜主题被修改后调用：主题 id 没变但配色变了，
  /// 需要阅读器强制刷新一次调色板。
  final VoidCallback? onThemeConfigChanged;
  final VoidCallback onPageModeTap;
  final ReaderAutoPageTurnController? autoPageTurnController;
  final bool autoPageTurnIsVertical;
  final VoidCallback? onAutoPageTurnSettings;
  final VoidCallback onTopBarStyleTap;
  final VoidCallback onTapZonesTap;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<int> onTextBrightnessChanged;
  final ValueChanged<bool> onDimTextInDarkModeChanged;
  final ValueChanged<int> onFontWeightChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<ReaderTextAlignment> onTextAlignmentChanged;
  final ValueChanged<int> onFirstLineIndentChanged;
  final ValueChanged<int> onParagraphSpacingChanged;
  final ValueChanged<double> onHorizontalMarginChanged;
  final ValueChanged<double> onTopMarginChanged;
  final ValueChanged<double> onBottomMarginChanged;
  final ValueChanged<bool> onPullBookmarkChanged;
  final ValueChanged<bool> onTapPageAnimationChanged;
  final ValueChanged<bool> onTabletTwoPageChanged;
  final ValueChanged<bool> onChapterTitlePageChanged;

  /// 页眉 / 页脚当前配置（打开面板时的快照）。
  final ReaderHeaderFooterSettings headerFooter;

  /// 页眉页脚 Tab 的文案。
  final ReaderHeaderFooterLabels headerFooterLabels;

  final ValueChanged<ReaderHeaderFooterSettings> onHeaderFooterChanged;

  /// 顶部提示（上下滚动模式、双页模式等）。
  final String? headerFooterHint;

  /// 头部右侧「完成」按钮文案；为空时不显示。
  final String? doneLabel;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late String _themeId = widget.themeId;
  late ReaderChapterProgressStyle _chapterProgressStyle =
      widget.chapterProgressStyle;
  late double _fontSize = widget.fontSize;
  late int _textBrightness = widget.textBrightness;
  late bool _dimTextInDarkMode = widget.dimTextInDarkMode;
  late int _fontWeight = normalizeReaderFontWeight(widget.fontWeight);
  late String _fontFamilyValueLabel = widget.fontFamilyValueLabel;
  late String _fontFamilyHint = widget.fontFamilyHint;
  late String? _fontFamily = widget.fontFamily;
  late List<String> _fontFamilyFallback = widget.fontFamilyFallback;
  late bool _fontWeightSupportsVariable = widget.fontWeightSupportsVariable;
  late int? _fontWeightVariableMin = widget.fontWeightVariableMin;
  late int? _fontWeightVariableMax = widget.fontWeightVariableMax;
  late String _fontWeightHint = widget.fontWeightHint;
  late double _lineHeight = widget.lineHeight;
  late double _letterSpacing = widget.letterSpacing;
  late ReaderTextAlignment _textAlignment = widget.textAlignment;
  late int _firstLineIndent = widget.firstLineIndent;
  late int _paragraphSpacing = widget.paragraphSpacing;
  late double _horizontalMargin = widget.horizontalMargin;
  late double _topMargin = widget.topMargin;
  late double _bottomMargin = widget.bottomMargin;
  late bool _pullBookmarkEnabled = widget.pullBookmarkEnabled;
  late bool _tapPageAnimationEnabled = widget.tapPageAnimationEnabled;
  late bool _tabletTwoPageEnabled = widget.tabletTwoPageEnabled;
  late bool _chapterTitlePageEnabled = widget.chapterTitlePageEnabled;
  late ReaderHeaderFooterSettings _headerFooter = widget.headerFooter;
  _ReaderSettingsTab _tab = _ReaderSettingsTab.theme;
  int _tabDirection = 1;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderThemes.byId(
      _themeId,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return ReaderSettingsSheetFrame(
      palette: palette,
      maxHeightFactor: 0.72,
      header: Row(
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.readerSettingsLiveHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
            ),
          ),
          const Spacer(),
          if (widget.onRestoreDesignDefaults != null)
            IconButton(
              key: const ValueKey('reader-settings-restore-defaults'),
              tooltip: context.l10n.readerRestoreDesignDefaults,
              onPressed: () => unawaited(_confirmRestoreDesignDefaults()),
              icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
              color: palette.secondaryText,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
            ),
          if (widget.doneLabel != null)
            TextButton(
              key: const ValueKey('reader-settings-done'),
              style: TextButton.styleFrom(
                foregroundColor: palette.accent,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.doneLabel!),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReaderThemeStrip(
            selectedThemeId: _themeId,
            labelFor: widget.themeLabelFor,
            onSelected: (themeId) {
              setState(() => _themeId = themeId);
              widget.onThemeChanged(themeId);
            },
            onCustomThemeTap: widget.onCustomThemeTap,
            onSystemThemeLongPress: () => unawaited(_showSystemThemeEditor()),
          ),
          const SizedBox(height: 12),
          _ReaderSettingsTabBar(
            palette: palette,
            current: _tab,
            labels: [
              widget.tabThemeLabel,
              widget.tabTextLabel,
              widget.tabLayoutLabel,
              widget.headerFooterLabels.tabLabel,
            ],
            onChanged: (nextTab) {
              if (nextTab == _tab) return;
              setState(() {
                _tabDirection = nextTab.index > _tab.index ? 1 : -1;
                _tab = nextTab;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildAnimatedTabContent(context, theme),
        ],
      ),
    );
  }

  Widget _buildAnimatedTabContent(BuildContext context, ThemeData theme) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final children = switch (_tab) {
      _ReaderSettingsTab.theme => _themeTabChildren(theme),
      _ReaderSettingsTab.text => [
        ..._textTabChildren(context),
        const Divider(height: 28),
        ..._pagingTabChildren(),
      ],
      _ReaderSettingsTab.layout => _layoutTabChildren(),
      _ReaderSettingsTab.chrome => _chromeTabChildren(theme),
    };
    final content = AnimatedSize(
      key: const ValueKey('reader-settings-tab-animated-size'),
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        key: const ValueKey('reader-settings-tab-switcher'),
        duration: duration,
        reverseDuration: duration,
        layoutBuilder: _readerSettingsTabLayout,
        transitionBuilder: (child, animation) {
          final childTab = (child.key! as ValueKey<_ReaderSettingsTab>).value;
          final incoming = childTab == _tab;
          final direction = incoming ? _tabDirection : -_tabDirection;
          return _ReaderSettingsTabTransition(
            animation: animation,
            interactiveWhenCompleted: incoming,
            horizontalOffset: direction * (incoming ? 0.045 : 0.025),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<_ReaderSettingsTab>(_tab),
          child: Column(
            key: ValueKey('reader-settings-tab-content-${_tab.name}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
    // 主题 / 文字与翻页 / 排版统一放进 hybrid 的圆角卡片；页眉页脚自带卡片。
    if (_tab == _ReaderSettingsTab.chrome) return content;
    return _SheetCard(theme: theme, child: content);
  }

  Future<void> _confirmRestoreDesignDefaults() async {
    final palette = ReaderThemes.byId(
      _themeId,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          context.l10n.readerRestoreDesignDefaults,
          style: TextStyle(fontSize: 16, color: palette.text),
        ),
        content: Text(
          context.l10n.readerRestoreDesignDefaultsConfirm,
          style: TextStyle(fontSize: 13, height: 1.5, color: palette.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onRestoreDesignDefaults?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _changeFontFamily() async {
    final choice = await widget.onFontFamilyTap();
    if (!mounted || choice == null) return;
    setState(() {
      _fontFamilyValueLabel = choice.valueLabel;
      _fontFamilyHint = choice.hint;
      _fontFamily = choice.family;
      _fontFamilyFallback = choice.fallbackFamilies;
      _fontWeightSupportsVariable = choice.supportsVariableWeight;
      _fontWeightVariableMin = choice.variableWeightMin;
      _fontWeightVariableMax = choice.variableWeightMax;
      _fontWeightHint = choice.fontWeightHint;
    });
  }

  List<Widget> _textTabChildren(BuildContext context) => [
    ReaderFontFamilyControl(
      label: widget.fontFamilyLabel,
      valueLabel: _fontFamilyValueLabel,
      hint: _fontFamilyHint,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      onTap: () => unawaited(_changeFontFamily()),
    ),
    ReaderSettingSlider(
      key: const ValueKey('reader-font-size-slider'),
      label: widget.fontSizeLabel,
      value: _fontSize,
      valueLabel: _fontSize.round().toString(),
      min: ReaderSettings.minFontSize,
      max: ReaderSettings.maxFontSize,
      divisions: (ReaderSettings.maxFontSize - ReaderSettings.minFontSize)
          .round(),
      onChanged: (value) => setState(() => _fontSize = value),
      onChangeEnd: widget.onFontSizeChanged,
    ),
    ReaderSettingSlider(
      key: const ValueKey('reader-text-brightness-slider'),
      label: widget.textBrightnessLabel,
      value: _textBrightness.toDouble(),
      valueLabel: _textBrightness.toString(),
      min: ReaderSettings.minTextBrightness.toDouble(),
      max: ReaderSettings.maxTextBrightness.toDouble(),
      divisions: ReaderSettings.maxTextBrightness,
      onChanged: (value) => setState(() => _textBrightness = value.round()),
      onChangeEnd: (value) => widget.onTextBrightnessChanged(value.round()),
    ),
    SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.only(bottom: 10),
      title: Text(widget.dimTextInDarkModeTitle),
      subtitle: Text(widget.dimTextInDarkModeHint),
      value: _dimTextInDarkMode,
      onChanged: (value) {
        setState(() => _dimTextInDarkMode = value);
        widget.onDimTextInDarkModeChanged(value);
      },
    ),
    ReaderFontWeightControl(
      label: widget.fontWeightLabel,
      valueLabels: widget.fontWeightValueLabels,
      hint: _fontWeightHint,
      previewText: widget.fontWeightPreviewText,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      fontWeightSupportsVariable: _fontWeightSupportsVariable,
      fontWeightVariableMin: _fontWeightVariableMin,
      fontWeightVariableMax: _fontWeightVariableMax,
      value: _fontWeight,
      onChanged: (value) => setState(() => _fontWeight = value),
      onChangeEnd: widget.onFontWeightChanged,
    ),
    ReaderSettingSlider(
      key: const ValueKey('reader-line-height-slider'),
      label: widget.lineHeightLabel,
      value: _lineHeight,
      valueLabel: _lineHeight.toStringAsFixed(1),
      min: ReaderSettings.minLineHeight,
      max: ReaderSettings.maxLineHeight,
      divisions:
          ((ReaderSettings.maxLineHeight - ReaderSettings.minLineHeight) * 10)
              .round(),
      onChanged: (value) => setState(() => _lineHeight = value),
      onChangeEnd: widget.onLineHeightChanged,
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.textAlignmentLabel,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ReaderTextAlignment>(
            key: const ValueKey('reader-text-alignment-control'),
            expandedInsets: EdgeInsets.zero,
            segments: [
              ButtonSegment(
                value: ReaderTextAlignment.natural,
                label: Text(widget.textAlignmentNaturalLabel),
              ),
              ButtonSegment(
                value: ReaderTextAlignment.justified,
                label: Text(widget.textAlignmentJustifiedLabel),
              ),
            ],
            selected: {_textAlignment},
            onSelectionChanged: (selection) {
              final value = selection.first;
              setState(() => _textAlignment = value);
              widget.onTextAlignmentChanged(value);
            },
          ),
        ],
      ),
    ),
    ExpansionTile(
      key: const ValueKey('reader-advanced-typography-tile'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(widget.advancedTypographyTitle),
      subtitle: Text(
        '${widget.letterSpacingLabel} · ${widget.firstLineIndentLabel}'
        ' · ${widget.paragraphSpacingLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        ReaderSettingSlider(
          key: const ValueKey('reader-letter-spacing-slider'),
          label: widget.letterSpacingLabel,
          value: _letterSpacing,
          valueLabel: _letterSpacing.toStringAsFixed(1),
          min: ReaderSettings.minLetterSpacing,
          max: ReaderSettings.maxLetterSpacing,
          divisions:
              ((ReaderSettings.maxLetterSpacing -
                          ReaderSettings.minLetterSpacing) *
                      10)
                  .round(),
          onChanged: (value) => setState(() => _letterSpacing = value),
          onChangeEnd: widget.onLetterSpacingChanged,
        ),
        ReaderSettingSlider(
          key: const ValueKey('reader-first-line-indent-slider'),
          label: widget.firstLineIndentLabel,
          value: _firstLineIndent.toDouble(),
          valueLabel: _firstLineIndent.toString(),
          min: 0,
          max: 4,
          divisions: 4,
          onChanged: (value) =>
              setState(() => _firstLineIndent = value.round()),
          onChangeEnd: (value) =>
              widget.onFirstLineIndentChanged(value.round()),
        ),
        ReaderSettingSlider(
          key: const ValueKey('reader-paragraph-spacing-slider'),
          label: widget.paragraphSpacingLabel,
          value: _paragraphSpacing.toDouble(),
          valueLabel: _paragraphSpacing.toString(),
          min: 0,
          max: 2,
          divisions: 2,
          onChanged: (value) =>
              setState(() => _paragraphSpacing = value.round()),
          onChangeEnd: (value) =>
              widget.onParagraphSpacingChanged(value.round()),
        ),
      ],
    ),
  ];

  List<Widget> _layoutTabChildren() => [
    if (widget.showChapterTitlePageToggle)
      SwitchListTile(
        key: const ValueKey('reader-chapter-title-page-switch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.title_rounded),
        value: _chapterTitlePageEnabled,
        title: Text(widget.chapterTitlePageTitle),
        subtitle: Text(widget.chapterTitlePageHint),
        onChanged: (value) {
          setState(() => _chapterTitlePageEnabled = value);
          widget.onChapterTitlePageChanged(value);
        },
      ),
    ReaderSettingSlider(
      key: const ValueKey('reader-horizontal-margin-slider'),
      label: widget.horizontalMarginLabel,
      value: _horizontalMargin,
      valueLabel: _horizontalMargin.round().toString(),
      min: ReaderMarginSettings.horizontalMin,
      max: ReaderMarginSettings.horizontalMax,
      divisions:
          (ReaderMarginSettings.horizontalMax -
                  ReaderMarginSettings.horizontalMin)
              .round(),
      onChanged: (value) => setState(() => _horizontalMargin = value),
      onChangeEnd: widget.onHorizontalMarginChanged,
    ),
    ReaderMarginControls(
      topLabel: widget.topMarginLabel,
      bottomLabel: widget.bottomMarginLabel,
      topMargin: _topMargin,
      bottomMargin: _bottomMargin,
      onTopChanged: (value) => setState(() => _topMargin = value),
      onBottomChanged: (value) => setState(() => _bottomMargin = value),
      onTopChangeEnd: widget.onTopMarginChanged,
      onBottomChangeEnd: widget.onBottomMarginChanged,
    ),
  ];

  String _themeDisplayName(ReaderThemePalette palette) {
    final custom = ReaderThemes.customThemeById(palette.id);
    if (custom != null && custom.name.trim().isNotEmpty) {
      return custom.name.trim();
    }
    return widget.themeLabelFor(palette.id);
  }

  /// 长按「跟随系统」：分别指定白天与夜晚使用的主题。
  Future<void> _showSystemThemeEditor() async {
    var dayId = ReaderThemes.systemDayThemeId;
    var nightId = ReaderThemes.systemNightThemeId;
    final options = ReaderThemes.orderedPalettes
        .where((palette) => palette.id != ReaderThemes.systemId)
        .toList(growable: false);
    if (options.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = Theme.of(context);
          Widget chipRow(
            String selectedId,
            Future<void> Function(String id) onPick,
          ) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final palette in options)
                  ChoiceChip(
                    selected: palette.id == selectedId,
                    onSelected: (_) => unawaited(onPick(palette.id)),
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: palette.background,
                    ),
                    label: Text(_themeDisplayName(palette)),
                  ),
              ],
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('跟随系统', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '分别指定白天和夜晚使用的主题。修改后立即生效。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Text('白天使用', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  chipRow(dayId, (id) async {
                    dayId = id;
                    setSheetState(() {});
                    await ReaderThemes.setSystemThemePair(dayId: id);
                    widget.onThemeConfigChanged?.call();
                  }),
                  const SizedBox(height: 20),
                  Text('夜晚使用', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  chipRow(nightId, (id) async {
                    nightId = id;
                    setSheetState(() {});
                    await ReaderThemes.setSystemThemePair(nightId: id);
                    widget.onThemeConfigChanged?.call();
                  }),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _themeTabChildren(ThemeData theme) => [
    Text(widget.themeDescription, style: theme.textTheme.bodySmall),
    const Divider(height: 28),
    ListTile(
      key: const ValueKey('reader-top-bar-style-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.vertical_align_top_rounded),
      title: Text(widget.topBarStyleTitle),
      subtitle: Text(widget.topBarStyleSummary),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onTopBarStyleTap,
    ),
    if (widget.onChapterProgressStyleChanged != null)
      ReaderChapterProgressSettingTile(
        style: _chapterProgressStyle,
        onChanged: (style) {
          setState(() => _chapterProgressStyle = style);
          widget.onChapterProgressStyleChanged!(style);
        },
      ),
  ];

  List<Widget> _pagingTabChildren() => [
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.swap_calls),
      title: Text(widget.pageModeTitle),
      subtitle: Text(widget.pageModeSummary),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onPageModeTap,
    ),
    if (widget.onAutoPageTurnSettings != null)
      if (widget.autoPageTurnController case final controller?)
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => _autoPageTurnTile(context, controller),
        )
      else
        _autoPageTurnTile(context, null),
    if (widget.onAutoPageTurnSettings != null)
      if (widget.autoPageTurnController case final controller?)
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => SwitchListTile(
            key: const ValueKey('reader-auto-page-turn-shortcut-switch'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.touch_app_rounded),
            value: controller.shortcutVisible,
            title: Text(context.l10n.readerAutoPageTurnShortcutTitle),
            subtitle: Text(context.l10n.readerAutoPageTurnShortcutHint),
            onChanged: (value) =>
                unawaited(controller.setShortcutVisible(value)),
          ),
        ),
    if (widget.showTabletTwoPageToggle)
      SwitchListTile(
        key: const ValueKey('reader-tablet-two-page-switch'),
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.menu_book_rounded),
        value: _tabletTwoPageEnabled,
        title: Text(widget.tabletTwoPageTitle),
        subtitle: Text(widget.tabletTwoPageHint),
        onChanged: (value) {
          setState(() => _tabletTwoPageEnabled = value);
          widget.onTabletTwoPageChanged(value);
        },
      ),
    SwitchListTile(
      key: const ValueKey('reader-tap-page-animation-switch'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.animation_rounded),
      value: _tapPageAnimationEnabled,
      title: Text(widget.tapPageAnimationTitle),
      subtitle: Text(widget.tapPageAnimationHint),
      onChanged: (value) {
        setState(() => _tapPageAnimationEnabled = value);
        widget.onTapPageAnimationChanged(value);
      },
    ),
    ListTile(
      key: const ValueKey('reader-tap-zones-tile'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.grid_view_rounded),
      title: Text(widget.tapZonesTitle),
      subtitle: Text(widget.tapZonesHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.onTapZonesTap,
    ),
    SwitchListTile(
      key: const ValueKey('reader-pull-bookmark-switch'),
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.bookmark_add_outlined),
      value: _pullBookmarkEnabled,
      title: Text(widget.pullBookmarkTitle),
      subtitle: Text(widget.pullBookmarkHint),
      onChanged: (value) {
        setState(() => _pullBookmarkEnabled = value);
        widget.onPullBookmarkChanged(value);
      },
    ),
  ];

  /// 第 4 个 Tab：页眉 / 页脚内容、位置与字号。
  List<Widget> _chromeTabChildren(ThemeData theme) {
    final labels = widget.headerFooterLabels;
    final headerEnabled = _headerFooter.headerEnabled;
    final footerEnabled = _headerFooter.footerEnabled;

    Widget section({
      required String title,
      required String switchTitle,
      required bool enabled,
      required ValueChanged<bool> onEnabled,
      required List<Widget> children,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.28,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(switchTitle),
              value: enabled,
              onChanged: onEnabled,
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: enabled ? 1 : 0.45,
              child: IgnorePointer(
                ignoring: !enabled,
                child: Column(children: children),
              ),
            ),
          ],
        ),
      );
    }

    Widget positionControl({
      required Key key,
      required ReaderChromePosition selected,
      required ValueChanged<ReaderChromePosition> onChanged,
    }) {
      return SegmentedButton<ReaderChromePosition>(
        key: key,
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        segments: [
          ButtonSegment(
            value: ReaderChromePosition.split,
            label: Text(labels.positionSplit),
          ),
          ButtonSegment(
            value: ReaderChromePosition.left,
            label: Text(labels.positionLeft),
          ),
          ButtonSegment(
            value: ReaderChromePosition.center,
            label: Text(labels.positionCenter),
          ),
          ButtonSegment(
            value: ReaderChromePosition.right,
            label: Text(labels.positionRight),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
      );
    }

    return [
      if (widget.headerFooterHint != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.headerFooterHint!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      if (widget.showTabletTwoPageToggle)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.readerHeaderFooterSpreadHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      section(
        title: labels.headerSectionTitle,
        switchTitle: labels.headerEnabledTitle,
        enabled: headerEnabled,
        onEnabled: (value) =>
            _updateHeaderFooter(_headerFooter.copyWith(headerEnabled: value)),
        children: [
          Text(labels.headerEnabledHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('reader-header-chapter-chip'),
                label: Text(labels.headerChapterContent),
                selected: _headerFooter.headerShowChapter,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(headerShowChapter: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-header-book-chip'),
                label: Text(labels.headerBookContent),
                selected: _headerFooter.headerShowBook,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(headerShowBook: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-header-time-chip'),
                label: Text(labels.headerTimeContent),
                selected: _headerFooter.headerShowClock,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(headerShowClock: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-header-battery-chip'),
                label: Text(labels.headerBatteryContent),
                selected: _headerFooter.headerShowBattery,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(headerShowBattery: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              labels.headerPositionLabel,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 6),
          positionControl(
            key: const ValueKey('reader-header-position-control'),
            selected: _headerFooter.headerPosition,
            onChanged: (value) => _updateHeaderFooter(
              _headerFooter.copyWith(headerPosition: value),
            ),
          ),
          const SizedBox(height: 8),
          ReaderSettingSlider(
            key: const ValueKey('reader-header-font-size-slider'),
            label: labels.headerFontSizeLabel,
            value: _headerFooter.headerFontSize,
            valueLabel: _headerFooter.headerFontSize.round().toString(),
            min: ReaderHeaderFooterSettings.minFontSize,
            max: ReaderHeaderFooterSettings.maxFontSize,
            divisions: 8,
            onChanged: (value) => setState(
              () =>
                  _headerFooter = _headerFooter.copyWith(headerFontSize: value),
            ),
            onChangeEnd: (value) => _updateHeaderFooter(
              _headerFooter.copyWith(headerFontSize: value),
            ),
          ),
          Text(labels.headerTopBarHint, style: theme.textTheme.bodySmall),
        ],
      ),
      section(
        title: labels.footerSectionTitle,
        switchTitle: labels.footerEnabledTitle,
        enabled: footerEnabled,
        onEnabled: (value) =>
            _updateHeaderFooter(_headerFooter.copyWith(footerEnabled: value)),
        children: [
          Text(labels.footerEnabledHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('reader-footer-chapter-chip'),
                label: Text(labels.footerChapterContent),
                selected: _headerFooter.footerShowChapterProgress,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(footerShowChapterProgress: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-footer-page-chip'),
                label: Text(labels.footerPageContent),
                selected: _headerFooter.footerShowPage,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(footerShowPage: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-footer-percent-chip'),
                label: Text(labels.footerPercentContent),
                selected: _headerFooter.footerShowPercent,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(footerShowPercent: value),
                ),
              ),
              FilterChip(
                key: const ValueKey('reader-footer-remaining-chip'),
                label: Text(labels.footerRemainingContent),
                selected: _headerFooter.footerShowRemaining,
                onSelected: (value) => _updateHeaderFooter(
                  _headerFooter.copyWith(footerShowRemaining: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              labels.footerPositionLabel,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 6),
          positionControl(
            key: const ValueKey('reader-footer-position-control'),
            selected: _headerFooter.footerPosition,
            onChanged: (value) => _updateHeaderFooter(
              _headerFooter.copyWith(footerPosition: value),
            ),
          ),
          const SizedBox(height: 8),
          ReaderSettingSlider(
            key: const ValueKey('reader-footer-font-size-slider'),
            label: labels.footerFontSizeLabel,
            value: _headerFooter.footerFontSize,
            valueLabel: _headerFooter.footerFontSize.round().toString(),
            min: ReaderHeaderFooterSettings.minFontSize,
            max: ReaderHeaderFooterSettings.maxFontSize,
            divisions: 8,
            onChanged: (value) => setState(
              () =>
                  _headerFooter = _headerFooter.copyWith(footerFontSize: value),
            ),
            onChangeEnd: (value) => _updateHeaderFooter(
              _headerFooter.copyWith(footerFontSize: value),
            ),
          ),
        ],
      ),
    ];
  }

  void _updateHeaderFooter(ReaderHeaderFooterSettings value) {
    if (!mounted) return;
    setState(() => _headerFooter = value);
    widget.onHeaderFooterChanged(value);
  }

  Widget _autoPageTurnTile(
    BuildContext context,
    ReaderAutoPageTurnController? controller,
  ) => ListTile(
    key: const ValueKey('reader-auto-page-turn-tile'),
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.av_timer_rounded),
    title: Text(context.l10n.readerAutoPageTurnTitle),
    subtitle: Text(
      controller == null
          ? context.l10n.readerAutoPageTurnOff
          : _autoPageTurnSummary(context, controller),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: widget.onAutoPageTurnSettings,
  );

  String _autoPageTurnSummary(
    BuildContext context,
    ReaderAutoPageTurnController controller,
  ) {
    final mode = controller.modeFor(widget.autoPageTurnIsVertical);
    final label = switch (mode) {
      ReaderAutoPageTurnMode.timed => context.l10n.readerAutoPageTurnModeTimed,
      ReaderAutoPageTurnMode.sweep => context.l10n.readerAutoPageTurnModeSweep,
      ReaderAutoPageTurnMode.continuous =>
        context.l10n.readerAutoPageTurnModeContinuous,
      ReaderAutoPageTurnMode.interval =>
        context.l10n.readerAutoPageTurnModeInterval,
    };
    return context.l10n.readerAutoPageTurnModeValue(
      label,
      controller.secondsFor(mode).round(),
    );
  }
}

enum _ReaderSettingsTab { theme, text, layout, chrome }

Widget _readerSettingsTabLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) => Stack(
  alignment: Alignment.topLeft,
  clipBehavior: Clip.hardEdge,
  children: [
    for (final child in previousChildren)
      Positioned(left: 0, right: 0, top: 0, child: child),
    ?currentChild,
  ],
);

class _ReaderSettingsTabTransition extends StatelessWidget {
  const _ReaderSettingsTabTransition({
    required this.animation,
    required this.interactiveWhenCompleted,
    required this.horizontalOffset,
    required this.child,
  });

  final Animation<double> animation;
  final bool interactiveWhenCompleted;
  final double horizontalOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final fadeCurve = interactiveWhenCompleted
        ? const Interval(0.18, 1, curve: Curves.easeOutCubic)
        : const Interval(0.6, 1, curve: Curves.easeOutCubic);
    final opacity = animation.drive(CurveTween(curve: fadeCurve));
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final transitioning =
            !interactiveWhenCompleted ||
            animation.status != AnimationStatus.completed;
        return IgnorePointer(
          ignoring: transitioning,
          child: ExcludeSemantics(excluding: transitioning, child: child),
        );
      },
      child: FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(horizontalOffset, 0),
            end: Offset.zero,
          ).animate(motion),
          child: child,
        ),
      ),
    );
  }
}

class ReaderTopBarStyleSheet extends StatelessWidget {
  const ReaderTopBarStyleSheet({
    super.key,
    required this.palette,
    required this.title,
    required this.selectedStyle,
    required this.titleFor,
    required this.hintFor,
    required this.onSelected,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderTopBarStyle selectedStyle;
  final String Function(ReaderTopBarStyle style) titleFor;
  final String Function(ReaderTopBarStyle style) hintFor;
  final ValueChanged<ReaderTopBarStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return Theme(
      data: theme,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ReaderTopBarStyle>(
                groupValue: selectedStyle,
                onChanged: (style) {
                  if (style != null) onSelected(style);
                },
                child: Column(
                  children: [
                    for (final style in ReaderTopBarStyle.values)
                      RadioListTile<ReaderTopBarStyle>(
                        key: ValueKey('reader-top-bar-style-${style.name}'),
                        value: style,
                        contentPadding: EdgeInsets.zero,
                        secondary: _ReaderTopBarStylePreview(
                          style: style,
                          palette: palette,
                        ),
                        title: Text(titleFor(style)),
                        subtitle: Text(hintFor(style)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderTopBarStylePreview extends StatelessWidget {
  const _ReaderTopBarStylePreview({required this.style, required this.palette});

  final ReaderTopBarStyle style;
  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final muted = palette.secondaryText.withValues(alpha: 0.72);
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: 72,
        height: 44,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 10,
              child: switch (style) {
                ReaderTopBarStyle.system => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('9:41', style: TextStyle(fontSize: 5, color: muted)),
                    Icon(
                      Icons.signal_cellular_alt_rounded,
                      size: 7,
                      color: muted,
                    ),
                  ],
                ),
                ReaderTopBarStyle.reader => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('9:41', style: TextStyle(fontSize: 5, color: muted)),
                    Expanded(
                      child: Text(
                        '···',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 5, color: muted),
                      ),
                    ),
                    Icon(Icons.battery_full_rounded, size: 7, color: muted),
                  ],
                ),
                ReaderTopBarStyle.floating => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('9:41', style: TextStyle(fontSize: 5, color: muted)),
                    Icon(Icons.battery_full_rounded, size: 7, color: muted),
                  ],
                ),
                ReaderTopBarStyle.hidden => const SizedBox.shrink(),
              },
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: index == 2 ? 0.62 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.text.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              if (index != 2) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class ReaderPageModeSheet extends StatelessWidget {
  const ReaderPageModeSheet({
    super.key,
    required this.palette,
    required this.title,
    required this.selectedMode,
    required this.titleFor,
    required this.hintFor,
    required this.onSelected,
    this.scrollByChapter,
    this.scrollByChapterTitle,
    this.scrollByChapterOnHint,
    this.scrollByChapterOffHint,
    this.onScrollByChapterChanged,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderPageMode selectedMode;
  final String Function(ReaderPageMode mode) titleFor;
  final String Function(ReaderPageMode mode) hintFor;
  final ValueChanged<ReaderPageMode> onSelected;
  final bool? scrollByChapter;
  final String? scrollByChapterTitle;
  final String? scrollByChapterOnHint;
  final String? scrollByChapterOffHint;
  final ValueChanged<bool>? onScrollByChapterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return Theme(
      data: theme,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<ReaderPageMode>(
                groupValue: selectedMode,
                onChanged: (mode) {
                  if (mode != null) onSelected(mode);
                },
                child: Column(
                  children: ReaderPageMode.values
                      .expand((mode) sync* {
                        yield RadioListTile<ReaderPageMode>(
                          value: mode,
                          title: Text(titleFor(mode)),
                          subtitle: Text(hintFor(mode)),
                        );
                        if (mode == ReaderPageMode.verticalScroll &&
                            selectedMode == ReaderPageMode.verticalScroll &&
                            scrollByChapter != null) {
                          yield SwitchListTile(
                            contentPadding: const EdgeInsets.only(left: 24),
                            value: scrollByChapter!,
                            title: Text(scrollByChapterTitle!),
                            subtitle: Text(
                              scrollByChapter!
                                  ? scrollByChapterOnHint!
                                  : scrollByChapterOffHint!,
                            ),
                            onChanged: onScrollByChapterChanged,
                          );
                        }
                      })
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsSheetFrame extends StatelessWidget {
  const ReaderSettingsSheetFrame({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 20),
    this.header,
    this.maxHeightFactor = 0.5,
  });

  final ReaderThemePalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 固定头部（标题 + 完成按钮），不随内容滚动。
  final Widget? header;

  /// 面板最大高度占屏幕比例。
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    // 拖动横条必须留在滚动视图之外：放进滚动区后，下拉手势会被
    // 滚动视图消费，弹窗无法通过拖动收起。
    return Theme(
      data: palette.toThemeData(typography: Theme.of(context).textTheme),
      child: Material(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ReaderSettingsDragHandle(palette: palette),
                ),
                if (header != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                    child: header,
                  ),
                Flexible(
                  child: SingleChildScrollView(padding: padding, child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsDragHandle extends StatelessWidget {
  const ReaderSettingsDragHandle({super.key, required this.palette});

  final ReaderThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.secondaryText.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class ReaderThemeStrip extends StatefulWidget {
  const ReaderThemeStrip({
    super.key,
    required this.selectedThemeId,
    required this.labelFor,
    required this.onSelected,
    required this.onCustomThemeTap,
    this.onSystemThemeLongPress,
    this.palettes,
    this.showCustomAction = true,
    this.cardWidth = 64,
    this.spacing = 8,
  });

  final String selectedThemeId;
  final String Function(String themeId) labelFor;
  final ValueChanged<String> onSelected;
  final VoidCallback onCustomThemeTap;

  /// 长按「跟随系统」卡片：编辑白天 / 夜晚分别使用哪个主题。
  final VoidCallback? onSystemThemeLongPress;
  final List<ReaderThemePalette>? palettes;
  final bool showCustomAction;
  final double cardWidth;
  final double spacing;

  @override
  State<ReaderThemeStrip> createState() => _ReaderThemeStripState();
}

class _ReaderThemeStripState extends State<ReaderThemeStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    final delta = event.scrollDelta.dy.abs() >= event.scrollDelta.dx.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0) return;
    final position = _scrollController.position;
    final atLeadingBoundary =
        delta < 0 && _scrollController.offset <= position.minScrollExtent + 0.5;
    final atTrailingBoundary =
        delta > 0 && _scrollController.offset >= position.maxScrollExtent - 0.5;
    if (atLeadingBoundary || atTrailingBoundary) return;
    final nextOffset = (_scrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(nextOffset);
      }
    });
  }

  /// 首屏只放 5 张主卡（纸黄 / 白天 / 护眼 / 黑夜 / 自定义）；
  /// 其余主题统一进「自定义 / 更多主题」页，横向滚动不再一长串。
  static const List<String> _primaryThemeIds = <String>[
    'paper',
    'day',
    'green',
    'night',
  ];

  @override
  Widget build(BuildContext context) {
    final customThemes = ReaderThemes.customThemes;
    final allThemes = widget.palettes ?? ReaderThemes.orderedPalettes;
    final primary = allThemes
        .where((palette) => _primaryThemeIds.contains(palette.id))
        .toList(growable: false);
    final themes = <ReaderThemePalette>[
      ...primary,
      if (!primary.any((palette) => palette.id == widget.selectedThemeId))
        ...allThemes
            .where((palette) => palette.id == widget.selectedThemeId)
            .take(1),
    ];
    final inheritedScrollBehavior = ScrollConfiguration.of(context);
    return SizedBox(
      height: 78,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: ScrollConfiguration(
          behavior: inheritedScrollBehavior.copyWith(
            dragDevices: {
              ...inheritedScrollBehavior.dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            physics: const BouncingScrollPhysics(),
            itemCount: themes.length + (widget.showCustomAction ? 1 : 0),
            separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
            itemBuilder: (context, index) {
              if (widget.showCustomAction && index == themes.length) {
                final colors = Theme.of(context).colorScheme;
                return SizedBox(
                  width: widget.cardWidth,
                  child: Semantics(
                    button: true,
                    label: widget.labelFor(ReaderCustomTheme.legacyThemeId),
                    child: InkWell(
                      key: const ValueKey('reader-custom-theme-card'),
                      onTap: widget.onCustomThemeTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                                if (customThemes.isNotEmpty) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    '${customThemes.length}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Aa',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 19,
                                height: 1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.labelFor(ReaderCustomTheme.legacyThemeId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 9.5,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              final palette = themes[index];
              final customTheme = ReaderThemes.customThemeById(palette.id);
              final selected = palette.id == widget.selectedThemeId;
              final label =
                  customTheme == null || customTheme.name.trim().isEmpty
                  ? widget.labelFor(palette.id)
                  : customTheme.name.trim();
              return _ReaderThemeCard(
                key: ValueKey('reader-theme-${palette.id}'),
                width: widget.cardWidth,
                palette: palette,
                label: label,
                selected: selected,
                icon: customTheme == null
                    ? _iconFor(palette.id)
                    : customTheme.hasBackgroundImage
                    ? Icons.image_rounded
                    : Icons.palette_rounded,
                onTap: () => widget.onSelected(palette.id),
                onLongPress: palette.id == ReaderThemes.systemId
                    ? widget.onSystemThemeLongPress
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
    ReaderThemes.systemId => Icons.brightness_auto_rounded,
    'xian_tan_light' => Icons.landscape_outlined,
    'xian_tan_dark' => Icons.landscape_rounded,
    'ye_se_dark' => Icons.nightlight_round,
    'pureBlack' => Icons.brightness_1_rounded,
    'night' => Icons.dark_mode_rounded,
    'navy' => Icons.nights_stay_rounded,
    'parchment' => Icons.auto_stories_rounded,
    'paper' => Icons.description_outlined,
    'green' => Icons.eco_rounded,
    _ => Icons.light_mode_rounded,
  };
}

class _ReaderThemeCard extends StatelessWidget {
  const _ReaderThemeCard({
    super.key,
    this.width = 64,
    required this.palette,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final double width;
  final ReaderThemePalette palette;
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(14);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: cardRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: cardRadius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: cardRadius,
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: ReaderThemeBackground(
              palette: palette,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Text(
                          'Aa',
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 19,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 9.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 6,
                    child: Icon(
                      icon,
                      size: 11,
                      color: palette.secondaryText.withValues(alpha: 0.75),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.onAccent.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: palette.onAccent,
                        ),
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

class ReaderFontFamilyControl extends StatelessWidget {
  const ReaderFontFamilyControl({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.hint,
    required this.onTap,
    this.fontFamily,
    this.fontFamilyFallback = const <String>[],
  });

  final String label;
  final String valueLabel;
  final String hint;
  final VoidCallback onTap;
  final String? fontFamily;
  final List<String> fontFamilyFallback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('reader-font-choice-tile'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFamilyFallback.isEmpty
                          ? null
                          : fontFamilyFallback,
                      color: colors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          inherit: false,
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFamilyFallback.isEmpty
                              ? null
                              : fontFamilyFallback,
                          color: colors.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderFontWeightControl extends StatelessWidget {
  const ReaderFontWeightControl({
    super.key,
    required this.label,
    required this.valueLabels,
    required this.hint,
    required this.previewText,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.fontFamily,
    this.fontFamilyFallback = const <String>[],
    this.fontWeightSupportsVariable = false,
    this.fontWeightVariableMin,
    this.fontWeightVariableMax,
  }) : assert(valueLabels.length == 5);

  final String label;
  final List<String> valueLabels;
  final String hint;
  final String previewText;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  final String? fontFamily;
  final List<String> fontFamilyFallback;
  final bool fontWeightSupportsVariable;
  final int? fontWeightVariableMin;
  final int? fontWeightVariableMax;

  int get _normalizedValue => normalizeReaderFontWeight(value);

  String get _valueLabel {
    final index = (_normalizedValue - ReaderSettings.minFontWeight) ~/ 100;
    return '${valueLabels[index]} · $_normalizedValue';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final previewStyle = TextStyle(
      inherit: false,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback.isEmpty
          ? null
          : fontFamilyFallback,
      color: colors.onSurface,
      fontSize: 18,
      height: 1.3,
      fontWeight: readerFontWeightFromValue(_normalizedValue),
      fontVariations: readerFontVariationsFromValue(
        _normalizedValue,
        supportsVariableWeight: fontWeightSupportsVariable,
        variableWeightMin: fontWeightVariableMin,
        variableWeightMax: fontWeightVariableMax,
      ),
    );
    return Padding(
      key: const ValueKey('reader-font-weight-control'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 86),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _valueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              style: previewStyle,
              child: Text(
                previewText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
              trackHeight: 4,
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outlineVariant,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              key: const ValueKey('reader-font-weight-slider'),
              value: _normalizedValue.toDouble(),
              min: ReaderSettings.minFontWeight.toDouble(),
              max: ReaderSettings.maxFontWeight.toDouble(),
              divisions:
                  (ReaderSettings.maxFontWeight -
                      ReaderSettings.minFontWeight) ~/
                  100,
              semanticFormatterCallback: (_) => _valueLabel,
              onChanged: (next) => onChanged(normalizeReaderFontWeight(next)),
              onChangeEnd: (next) =>
                  onChangeEnd(normalizeReaderFontWeight(next)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReaderSettingSlider extends StatelessWidget {
  const ReaderSettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
              trackHeight: 4,
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.outlineVariant,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderMarginControls extends StatelessWidget {
  const ReaderMarginControls({
    super.key,
    required this.topLabel,
    required this.bottomLabel,
    required this.topMargin,
    required this.bottomMargin,
    required this.onTopChanged,
    required this.onBottomChanged,
    this.onTopChangeEnd,
    this.onBottomChangeEnd,
  });

  final String topLabel;
  final String bottomLabel;
  final double topMargin;
  final double bottomMargin;
  final ValueChanged<double> onTopChanged;
  final ValueChanged<double> onBottomChanged;
  final ValueChanged<double>? onTopChangeEnd;
  final ValueChanged<double>? onBottomChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ReaderSettingSlider(
        key: const ValueKey('reader-top-margin-slider'),
        label: topLabel,
        value: topMargin,
        valueLabel: topMargin.round().toString(),
        min: ReaderMarginSettings.min,
        max: ReaderMarginSettings.max,
        divisions: (ReaderMarginSettings.max - ReaderMarginSettings.min)
            .round(),
        onChanged: onTopChanged,
        onChangeEnd: onTopChangeEnd,
      ),
      ReaderSettingSlider(
        key: const ValueKey('reader-bottom-margin-slider'),
        label: bottomLabel,
        value: bottomMargin,
        valueLabel: bottomMargin.round().toString(),
        min: ReaderMarginSettings.min,
        max: ReaderMarginSettings.max,
        divisions: (ReaderMarginSettings.max - ReaderMarginSettings.min)
            .round(),
        onChanged: onBottomChanged,
        onChangeEnd: onBottomChangeEnd,
      ),
    ],
  );
}

/// 面板的圆角内容卡片（对齐 hybrid 的 `.card`）。
class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// hybrid 的页签条：灰底圆角容器 + 选中项白底胶囊，替代 Material SegmentedButton。
/// 字号压到 10.5，四个页签在 320dp 也不会挤出去。
class _ReaderSettingsTabBar extends StatelessWidget {
  const _ReaderSettingsTabBar({
    required this.palette,
    required this.current,
    required this.labels,
    required this.onChanged,
  });

  final ReaderThemePalette palette;
  final _ReaderSettingsTab current;
  final List<String> labels;
  final ValueChanged<_ReaderSettingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.controlFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _ReaderSettingsTab.values.length; i++)
            Expanded(
              child: _ReaderSettingsTabButton(
                palette: palette,
                label: labels[i],
                selected: _ReaderSettingsTab.values[i] == current,
                onTap: () => onChanged(_ReaderSettingsTab.values[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReaderSettingsTabButton extends StatelessWidget {
  const _ReaderSettingsTabButton({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ReaderThemePalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.35),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? palette.text : palette.secondaryText,
          ),
        ),
      ),
    );
  }
}
