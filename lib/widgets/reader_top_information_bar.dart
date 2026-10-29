import 'package:flutter/material.dart';

import '../core/reader/reader_header_footer_settings.dart';
import '../core/reader/reader_leaf_status.dart';
import '../core/reader/reader_safe_area.dart';
import '../utils/reader_themes.dart';

enum ReaderTopInformationLayout { full, spreadLeft, spreadRight }

/// 页眉：章节 / 书名 / 时间 / 电量，内容与对齐方式由
/// [ReaderHeaderFooterSettings] 决定；默认值仍是旧版「时间左 / 章节中 / 电量右」。
class ReaderTopInformationBar extends StatelessWidget {
  const ReaderTopInformationBar({
    super.key,
    required this.palette,
    required this.title,
    required this.status,
    this.layout = ReaderTopInformationLayout.full,
    this.bookTitle = '',
    this.settings = const ReaderHeaderFooterSettings(),
    this.height = ReaderSafeAreaMetrics.readerTopBarHeight,
  });

  final ReaderThemePalette palette;
  final String title;
  final ReaderLeafStatusData? status;
  final ReaderTopInformationLayout layout;

  /// 书名；只有 `settings.headerShowBook` 为 true 时才显示。
  final String bookTitle;

  final ReaderHeaderFooterSettings settings;

  /// 页眉高度（由安全区按字号算出）。
  final double height;

  @override
  Widget build(BuildContext context) {
    final showChapter = settings.headerShowChapter;
    final showBook = settings.headerShowBook;
    final showClock = settings.headerShowClock;
    final showBattery = settings.headerShowBattery;

    final titleParts = <String>[
      if (showChapter) title,
      if (showBook) bookTitle,
    ].where((value) => value.isNotEmpty).toList(growable: false);
    final displayTitle = titleParts.join(' · ');

    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(
          height: 1,
          fontSize: settings.headerFontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          height: 1,
          fontSize: settings.headerFontSize,
          fontWeight: FontWeight.w500,
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final titleStyle = style.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14,
    );

    final time = showClock && status != null
        ? MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(status!.time),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          )
        : '';
    final battery = showBattery ? status?.battery : null;

    final batteryIndicator = battery == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                battery.charging
                    ? Icons.battery_charging_full_rounded
                    : _batteryIcon(battery.level),
                size: settings.headerFontSize + 1,
                color: style.color,
              ),
              const SizedBox(width: 1),
              Text('${battery.level}%', style: style),
            ],
          );

    final semanticsParts = <String>[
      if (time.isNotEmpty) time,
      if (displayTitle.isNotEmpty) displayTitle,
      if (battery != null) '${battery.level}%',
    ];

    return Semantics(
      container: true,
      label: semanticsParts.join(', '),
      child: SizedBox(
        height: height,
        child: switch (layout) {
          ReaderTopInformationLayout.full =>
            settings.headerPosition == ReaderChromePosition.split
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(time, style: style),
                      ),
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.54,
                          child: Text(
                            displayTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                      ),
                      if (batteryIndicator != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: batteryIndicator,
                        ),
                    ],
                  )
                : _buildJoined(
                    settings.headerPosition,
                    semanticsParts,
                    titleStyle,
                  ),
          ReaderTopInformationLayout.spreadLeft => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          ReaderTopInformationLayout.spreadRight => Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (time.isNotEmpty) Text(time, style: style),
                if (time.isNotEmpty && batteryIndicator != null)
                  const SizedBox(width: 8),
                ?batteryIndicator,
              ],
            ),
          ),
        },
      ),
    );
  }

  /// 非「分散」布局：所有已选内容用 ` · ` 连成一行，整体左 / 中 / 右对齐。
  Widget _buildJoined(
    ReaderChromePosition position,
    List<String> parts,
    TextStyle style,
  ) {
    final text = parts.join(' · ');
    return switch (position) {
      ReaderChromePosition.left => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      ReaderChromePosition.right => Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      _ => Align(
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    };
  }
}

/// 灵动信息栏：占用被隐藏的系统状态栏区域，左侧时间、右侧电量，不挤占
/// 正文排版空间。
///
/// 翻页模式下由 `ReaderPaperPageLeaf` 画进纸页，随翻页动画一起移动；
/// 纵向滚动模式没有翻页概念，由 [ReaderFloatingStatusOverlay] 固定在
/// 视口顶部。双页 spread 时左页只显示时间、右页只显示电量。
class ReaderFloatingStatusBar extends StatelessWidget {
  const ReaderFloatingStatusBar({
    super.key,
    required this.palette,
    required this.status,
    this.layout = ReaderTopInformationLayout.full,
  });

  final ReaderThemePalette palette;
  final ReaderLeafStatusData? status;
  final ReaderTopInformationLayout layout;

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(
          height: 1,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08,
          color: palette.secondaryText.withValues(alpha: 0.72),
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          height: 1,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: palette.secondaryText.withValues(alpha: 0.72),
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final time = status == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(status!.time),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    final battery = status?.battery;
    final showTime =
        layout != ReaderTopInformationLayout.spreadRight && time.isNotEmpty;
    final showBattery =
        layout != ReaderTopInformationLayout.spreadLeft && battery != null;

    return Semantics(
      container: true,
      label: [
        if (showTime) time,
        if (showBattery) '${battery.level}%',
      ].join(', '),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showTime)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(time, style: style),
            ),
          if (showBattery)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    battery.charging
                        ? Icons.battery_charging_full_rounded
                        : _batteryIcon(battery.level),
                    size: 12,
                    color: style.color,
                  ),
                  const SizedBox(width: 1),
                  Text('${battery.level}%', style: style),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 纵向滚动模式下的灵动信息栏：固定在视口顶部的状态栏区域。
/// 作为阅读页顶层 Stack 的直接子节点使用。
class ReaderFloatingStatusOverlay extends StatelessWidget {
  const ReaderFloatingStatusOverlay({
    super.key,
    required this.palette,
    required this.status,
    required this.safeArea,
    required this.horizontalPadding,
  });

  final ReaderThemePalette palette;
  final ReaderLeafStatusData? status;
  final ReaderSafeAreaMetrics safeArea;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: safeArea.floatingStatusHeight,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ReaderFloatingStatusBar(palette: palette, status: status),
        ),
      ),
    );
  }
}

IconData _batteryIcon(int level) {
  if (level <= 15) return Icons.battery_1_bar_rounded;
  if (level <= 35) return Icons.battery_2_bar_rounded;
  if (level <= 55) return Icons.battery_3_bar_rounded;
  if (level <= 75) return Icons.battery_5_bar_rounded;
  if (level <= 90) return Icons.battery_6_bar_rounded;
  return Icons.battery_full_rounded;
}
