import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 阅读正文相对系统安全区的统一布局指标。
///
/// 系统 inset 与用户选择的阅读边距各司其职：顶部确保正文落在刘海/灵动岛
/// 下方。页码可以落在系统底部安全区内、但保持在 Home Indicator 上方；
/// 正文上下边距可以分别调整，且不会带动页码位置。
class ReaderSafeAreaMetrics {
  static const double pageNumberReserve = 12.0;
  static const double pageNumberGap = 4.0;
  static const double readerTopBarHeight = 16.0;
  static const double readerTopBarGap = 8.0;
  static const double readerTopBarReserve =
      readerTopBarHeight + readerTopBarGap;
  static const double _pageNumberSafeAreaOverlap = 20.0;
  static const double _minimumPageNumberBottom = 8.0;

  /// 状态栏 inset 随隐藏一起归零的设备（无刘海直屏）上，灵动信息栏仍按
  /// 普通状态栏高度画在页面最顶端。
  static const double floatingStatusMinHeight = 24.0;

  final EdgeInsets viewPadding;
  final double topMargin;
  final double bottomMargin;
  final double topChromeReserve;

  /// 页脚是否显示；关闭后正文可以压回页码原本占的高度。
  final bool showFooter;

  /// 页眉高度（只用于绘制页眉；正文预留由 [topChromeReserve] 决定）。
  final double headerHeight;

  /// 页脚高度；比默认的页码高度更高时正文会相应上移。
  final double footerHeight;

  const ReaderSafeAreaMetrics({
    required this.viewPadding,
    required this.topMargin,
    required this.bottomMargin,
    this.topChromeReserve = 0,
    this.showFooter = true,
    this.headerHeight = readerTopBarHeight,
    this.footerHeight = pageNumberReserve,
  });

  double get contentTop => viewPadding.top + topChromeReserve + topMargin;

  double get readerTopBarTop => viewPadding.top + 4;

  /// 灵动信息栏占用的区域高度：即被隐藏的系统状态栏区域。
  double get floatingStatusHeight =>
      math.max(viewPadding.top, floatingStatusMinHeight);

  double get pageNumberBottom => math.max(
    _minimumPageNumberBottom,
    viewPadding.bottom - _pageNumberSafeAreaOverlap,
  );

  double get contentBottom => math.max(
    viewPadding.bottom + bottomMargin,
    showFooter ? pageNumberBottom + footerHeight + pageNumberGap : 0.0,
  );

  String get paginationSignature =>
      '${contentTop.toStringAsFixed(2)}:${contentBottom.toStringAsFixed(2)}:'
      '${topChromeReserve.toStringAsFixed(2)}';
}
