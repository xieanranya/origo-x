import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 页眉 / 页脚内容的对齐方式。
///
/// `split` 是「分散」：页眉为时间居左 / 章节居中 / 电量居右，页脚为
/// 章节进度居左 / 页码居右；其余三项把已选内容用 ` · ` 连接后整体对齐。
enum ReaderChromePosition { split, left, center, right }

/// 阅读页页眉 / 页脚配置。
///
/// 默认值与旧版固定布局一致（页眉 16 高、页脚 12 高、显示章节 / 时间 / 电量、
/// 页脚显示章节进度与页码），保证老用户升级后看不出变化。
@immutable
class ReaderHeaderFooterSettings {
  static const double minFontSize = 8;
  static const double maxFontSize = 16;
  static const double defaultHeaderFontSize = 10;
  static const double defaultFooterFontSize = 10;
  static const double _headerMinHeight = 16;
  static const double _footerMinHeight = 12;

  const ReaderHeaderFooterSettings({
    this.headerEnabled = true,
    this.headerShowChapter = true,
    this.headerShowBook = false,
    this.headerShowClock = true,
    this.headerShowBattery = true,
    this.headerPosition = ReaderChromePosition.split,
    this.headerFontSize = defaultHeaderFontSize,
    this.footerEnabled = true,
    this.footerShowChapterProgress = true,
    this.footerShowPage = true,
    this.footerShowPercent = false,
    this.footerShowRemaining = false,
    this.footerPosition = ReaderChromePosition.split,
    this.footerFontSize = defaultFooterFontSize,
  });

  final bool headerEnabled;
  final bool headerShowChapter;
  final bool headerShowBook;
  final bool headerShowClock;
  final bool headerShowBattery;
  final ReaderChromePosition headerPosition;
  final double headerFontSize;

  final bool footerEnabled;
  final bool footerShowChapterProgress;
  final bool footerShowPage;
  final bool footerShowPercent;
  final bool footerShowRemaining;
  final ReaderChromePosition footerPosition;
  final double footerFontSize;

  bool get showsHeader =>
      headerEnabled &&
      (headerShowChapter ||
          headerShowBook ||
          headerShowClock ||
          headerShowBattery);

  bool get showsFooter =>
      footerEnabled &&
      (footerShowChapterProgress ||
          footerShowPage ||
          footerShowPercent ||
          footerShowRemaining);

  double get headerHeight =>
      showsHeader ? math.max(_headerMinHeight, headerFontSize * 1.2) : 0.0;

  double get footerHeight =>
      showsFooter ? math.max(_footerMinHeight, footerFontSize * 1.2) : 0.0;

  /// 只有高度 / 是否显示会影响分页；内容与位置只影响重绘。
  String get layoutSignature =>
      '${showsHeader ? 1 : 0}:${headerHeight.toStringAsFixed(1)}:'
      '${showsFooter ? 1 : 0}:${footerHeight.toStringAsFixed(1)}';

  /// 给纸页快照缓存用；内容 / 位置变化也必须让快照失效。
  String get cacheSignature => [
    headerEnabled,
    headerShowChapter,
    headerShowBook,
    headerShowClock,
    headerShowBattery,
    headerPosition.name,
    headerFontSize.toStringAsFixed(1),
    footerEnabled,
    footerShowChapterProgress,
    footerShowPage,
    footerShowPercent,
    footerShowRemaining,
    footerPosition.name,
    footerFontSize.toStringAsFixed(1),
  ].join(':');

  ReaderHeaderFooterSettings copyWith({
    bool? headerEnabled,
    bool? headerShowChapter,
    bool? headerShowBook,
    bool? headerShowClock,
    bool? headerShowBattery,
    ReaderChromePosition? headerPosition,
    double? headerFontSize,
    bool? footerEnabled,
    bool? footerShowChapterProgress,
    bool? footerShowPage,
    bool? footerShowPercent,
    bool? footerShowRemaining,
    ReaderChromePosition? footerPosition,
    double? footerFontSize,
  }) {
    return ReaderHeaderFooterSettings(
      headerEnabled: headerEnabled ?? this.headerEnabled,
      headerShowChapter: headerShowChapter ?? this.headerShowChapter,
      headerShowBook: headerShowBook ?? this.headerShowBook,
      headerShowClock: headerShowClock ?? this.headerShowClock,
      headerShowBattery: headerShowBattery ?? this.headerShowBattery,
      headerPosition: headerPosition ?? this.headerPosition,
      headerFontSize: (headerFontSize ?? this.headerFontSize)
          .clamp(minFontSize, maxFontSize)
          .toDouble(),
      footerEnabled: footerEnabled ?? this.footerEnabled,
      footerShowChapterProgress:
          footerShowChapterProgress ?? this.footerShowChapterProgress,
      footerShowPage: footerShowPage ?? this.footerShowPage,
      footerShowPercent: footerShowPercent ?? this.footerShowPercent,
      footerShowRemaining: footerShowRemaining ?? this.footerShowRemaining,
      footerPosition: footerPosition ?? this.footerPosition,
      footerFontSize: (footerFontSize ?? this.footerFontSize)
          .clamp(minFontSize, maxFontSize)
          .toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'headerEnabled': headerEnabled,
    'headerShowChapter': headerShowChapter,
    'headerShowBook': headerShowBook,
    'headerShowClock': headerShowClock,
    'headerShowBattery': headerShowBattery,
    'headerPosition': headerPosition.name,
    'headerFontSize': headerFontSize,
    'footerEnabled': footerEnabled,
    'footerShowChapterProgress': footerShowChapterProgress,
    'footerShowPage': footerShowPage,
    'footerShowPercent': footerShowPercent,
    'footerShowRemaining': footerShowRemaining,
    'footerPosition': footerPosition.name,
    'footerFontSize': footerFontSize,
  };

  factory ReaderHeaderFooterSettings.fromJson(Map<String, Object?> json) {
    const defaults = ReaderHeaderFooterSettings();

    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    double readSize(String key, double fallback) {
      final value = json[key];
      final raw = value is num ? value.toDouble() : fallback;
      return raw.clamp(minFontSize, maxFontSize).toDouble();
    }

    ReaderChromePosition readPosition(
      String key,
      ReaderChromePosition fallback,
    ) {
      final value = json[key];
      if (value is String) {
        for (final position in ReaderChromePosition.values) {
          if (position.name == value) return position;
        }
      }
      return fallback;
    }

    return ReaderHeaderFooterSettings(
      headerEnabled: readBool('headerEnabled', defaults.headerEnabled),
      headerShowChapter: readBool(
        'headerShowChapter',
        defaults.headerShowChapter,
      ),
      headerShowBook: readBool('headerShowBook', defaults.headerShowBook),
      headerShowClock: readBool('headerShowClock', defaults.headerShowClock),
      headerShowBattery: readBool(
        'headerShowBattery',
        defaults.headerShowBattery,
      ),
      headerPosition: readPosition('headerPosition', defaults.headerPosition),
      headerFontSize: readSize('headerFontSize', defaults.headerFontSize),
      footerEnabled: readBool('footerEnabled', defaults.footerEnabled),
      footerShowChapterProgress: readBool(
        'footerShowChapterProgress',
        defaults.footerShowChapterProgress,
      ),
      footerShowPage: readBool('footerShowPage', defaults.footerShowPage),
      footerShowPercent: readBool(
        'footerShowPercent',
        defaults.footerShowPercent,
      ),
      footerShowRemaining: readBool(
        'footerShowRemaining',
        defaults.footerShowRemaining,
      ),
      footerPosition: readPosition('footerPosition', defaults.footerPosition),
      footerFontSize: readSize('footerFontSize', defaults.footerFontSize),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderHeaderFooterSettings &&
        other.headerEnabled == headerEnabled &&
        other.headerShowChapter == headerShowChapter &&
        other.headerShowBook == headerShowBook &&
        other.headerShowClock == headerShowClock &&
        other.headerShowBattery == headerShowBattery &&
        other.headerPosition == headerPosition &&
        other.headerFontSize == headerFontSize &&
        other.footerEnabled == footerEnabled &&
        other.footerShowChapterProgress == footerShowChapterProgress &&
        other.footerShowPage == footerShowPage &&
        other.footerShowPercent == footerShowPercent &&
        other.footerShowRemaining == footerShowRemaining &&
        other.footerPosition == footerPosition &&
        other.footerFontSize == footerFontSize;
  }

  @override
  int get hashCode => Object.hash(
    headerEnabled,
    headerShowChapter,
    headerShowBook,
    headerShowClock,
    headerShowBattery,
    headerPosition,
    headerFontSize,
    footerEnabled,
    footerShowChapterProgress,
    footerShowPage,
    footerShowPercent,
    footerShowRemaining,
    footerPosition,
    footerFontSize,
  );
}
