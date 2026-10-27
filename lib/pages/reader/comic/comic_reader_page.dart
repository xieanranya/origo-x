// 文件说明：漫画阅读页，界面与功能对齐 Perfect Viewer。
// 垂直连贯 / 水平左滑（由左至右）/ 水平右滑（由右至左）；
// 单页 / 双页 / 自动版面；符合宽度 / 符合高度 / 符合画面三种缩放；
// 自动分割双页扫描、自动侦测白边、逐项颜色调整、背光与过滤蓝光、
// 页面边界、空白封里、自动翻页、点击分区翻页。
// 技术要点：垂直「符合宽度」用变高列表让画面宽度铺满屏幕；画面用 CustomPainter
// 按归一化 src 直接绘制，颜色调整合成单个 4x5 矩阵交给 GPU。
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../models/book.dart';
import '../../../services/books/book_dao.dart';
import '../../../services/books/comic_archive_service.dart';
import '../../../services/reader/comic_view_settings.dart';
import 'comic_menu_panel.dart';

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  final BookDao _dao = BookDao();
  final ComicViewSettingsStore _settingsStore = const ComicViewSettingsStore();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);
  final Map<int, Rect?> _cropRects = <int, Rect?>{};
  final Set<int> _cropPending = <int>{};
  final Set<String> _aspectPending = <String>{};
  final _ComicImageCache _imageCache = _ComicImageCache();

  List<String> _images = const <String>[];
  Map<String, double> _aspects = const <String, double>{};
  List<ComicSpread> _spreads = const <ComicSpread>[];
  ComicViewSettings _settings = const ComicViewSettings();
  bool _loading = true;
  bool _controlsVisible = true;
  double _screenWidth = 0;
  /// 最近一次探测到的真实宽高比：同本漫画页面比例基本一致，可给未探测页兜底，
  /// 这样占位高度与真实高度一致，不会留下黑块。
  double _lastKnownAspect = 0;
  /// 正在拖动进度条时不响应滚动回调，避免两边互相抢导致来回跳。
  bool _draggingSlider = false;
  Timer? _saveDebounce;
  Timer? _autoTurnTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _itemPositionsListener.itemPositions.addListener(_handlePositions);
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _autoTurnTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _itemPositionsListener.itemPositions.removeListener(_handlePositions);
    _scrollController.dispose();
    _pageController.dispose();
    _currentIndex.dispose();
    _imageCache.dispose();
    _saveProgress();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _settings = await _settingsStore.load();
    final directory = Directory(widget.book.filePath);
    if (await directory.exists()) {
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) {
            final extension = p
                .extension(file.path)
                .replaceFirst('.', '')
                .toLowerCase();
            return ComicArchiveService.imageExtensions.contains(extension);
          })
          .toList();
      files.sort(
        (a, b) => ComicArchiveService.naturalCompare(
          p.basename(a.path),
          p.basename(b.path),
        ),
      );
      _images = files.map((file) => file.path).toList(growable: false);
    }
    // 先同步探测首屏这几页的真实比例（约 200ms），保证第一屏高度就是准的，
    // 不会出现「占位比图片高」的黑块；其余页在滚动到时按需补。
    if (_images.isNotEmpty) {
      final start = widget.book.currentPage.clamp(0, _images.length - 1);
      final from = math.max(0, start - 2);
      final to = math.min(_images.length, start + 6);
      final probed = await ComicPageComposer.probeAspects(
        _images.sublist(from, to),
      );
      if (probed.isNotEmpty) {
        _aspects = <String, double>{..._aspects, ...probed};
        _lastKnownAspect = probed.values.first;
      }
    }
    if (_settings.splitDoublePage && _images.isNotEmpty) {
      unawaited(_probeAllAspects());
    }
    _rebuildSpreads();
    _currentIndex.value = _indexForLogicalPage(widget.book.currentPage);
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpTo(_currentIndex.value),
    );
    _restartAutoTurn();
  }

  /// 后台串行探测比例，不阻塞界面；仅补足尚未记录的比例。
  Future<void> _probeAllAspects() async {
    const chunk = 24;
    for (var start = 0; start < _images.length; start += chunk) {
      final end = math.min(start + chunk, _images.length);
      final slice = _images.sublist(start, end);
      final probed = await ComicPageComposer.probeAspects(slice);
      if (!mounted) return;
      if (probed.isEmpty) continue;
      setState(() {
        _aspects = <String, double>{..._aspects, ...probed};
      });
    }
  }

  // ---------------------------------------------------------- 页面编排

  void _rebuildSpreads() {
    final frames = ComicPageComposer.expandFrames(
      paths: _images,
      aspects: _aspects,
      settings: _settings,
    );
    final composed = ComicPageComposer.composeSpreads(
      frames: frames,
      settings: _settings,
    );
    // 空白封里：在最前面插入一屏空白。
    _spreads = _settings.blankFirstPage
        ? <ComicSpread>[const ComicSpread(logicalPage: 0), ...composed]
        : composed;

  }

  int _indexForLogicalPage(int logicalPage) {
    if (_spreads.isEmpty) return 0;
    for (var index = 0; index < _spreads.length; index++) {
      if (_spreads[index].logicalPage >= logicalPage) return index;
    }
    return _spreads.length - 1;
  }

  int get _currentLogicalPage {
    if (_spreads.isEmpty) return 0;
    final index = _currentIndex.value.clamp(0, _spreads.length - 1);
    return _spreads[index].logicalPage;
  }

  /// 单帧在屏幕上应占的宽高比（已考虑双页切分区域）。
  /// 计算一帧最终要显示的区域：双页切分 → 白边侦测 → 手工裁切，三者取交集。
  /// 高度计算与画面绘制必须用同一份结果，否则容器与内容比例不一致会变形。
  Rect _effectiveSrc(ComicFrame frame) {
    var src = frame.src;
    // 白边检测是基于「整页」做的；若是双页切分出来的半页，
    // 套用整页的裁剪框会把画面裁偏（表现为上下/左右错位），必须跳过。
    final isDerivedFrame = frame.src != ComicPageComposer.fullRect;
    if (_settings.cropBorders && !isDerivedFrame) {
      final crop = _cropRects[frame.logicalPage];
      if (crop != null) {
        final combined = Rect.fromLTRB(
          math.max(src.left, crop.left),
          math.max(src.top, crop.top),
          math.min(src.right, crop.right),
          math.min(src.bottom, crop.bottom),
        );
        if (combined.width > 0.05 && combined.height > 0.05) {
          src = combined;
        }
      }
    }
    final manual = _settings.manualCrop;
    if (manual > 0) {
      final insetX = src.width * manual;
      final insetY = src.height * manual;
      if (src.width - insetX * 2 > 0.05 && src.height - insetY * 2 > 0.05) {
        src = Rect.fromLTRB(
          src.left + insetX,
          src.top + insetY,
          src.right - insetX,
          src.bottom - insetY,
        );
      }
    }
    return src;
  }

  /// 某帧在屏幕上的真实宽高比（已考虑实际裁剪区域）。
  double _displayAspect(ComicFrame frame) {
    final image = _imageCache.get(frame.imagePath);
    final base = image != null && image.height > 0
        ? image.width / image.height
        : (_aspects[frame.imagePath] ??
              (frame.imageAspect > 0 ? frame.imageAspect : 0.7));
    final src = _effectiveSrc(frame);
    final ratio = base * (src.width / src.height);
    if (image != null && image.height > 0) {
      _lastKnownAspect = ratio;
    }
    return ratio > 0.05 ? ratio : 0.7;
  }

  /// 某一屏在变高列表里的高度：屏宽 ÷ 该屏真实比例。
  double _heightOf(int index) {
    if (index < 0 || index >= _spreads.length) return 0;
    final width = _screenWidth > 0
        ? _screenWidth
        : MediaQuery.of(context).size.width;
    final frame = _spreads[index].left;
    final aspect = frame == null ? 1.0 : _displayAspect(frame);
    final known = aspect > 0.05
        ? aspect
        : (_lastKnownAspect > 0.05 ? _lastKnownAspect : 0.7);
    final raw = width / known;
    // 高度是小数时，相邻两项的像素边界取整会漏出 1px 背景（表现为一条黑线），
    // 这里按物理像素向上取整，保证两页严丝合缝。
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return (raw * dpr).ceilToDouble() / dpr;
  }

  // ---------------------------------------------------------------- 翻页

  /// 垂直卷动模式下用变高列表（每页按图片比例撑开，宽度铺满）。
  bool get _usesFitWidthList =>
      _settings.layout == ComicPageLayout.verticalScroll;

  void _jumpTo(int index) {
    if (_spreads.isEmpty) return;
    switch (_settings.layout) {
      case ComicPageLayout.page:
        if (_pageController.hasClients) _pageController.jumpToPage(index);
      case ComicPageLayout.verticalScroll:
        // 按页码跳转：列表内部知道每项真实位置，不受「总高度是估算值」影响。
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: index);
        }
      case ComicPageLayout.horizontalScroll:
        if (_scrollController.hasClients) {
          final width = MediaQuery.of(context).size.width;
          final target = (index * width).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(target);
        }
    }
  }

  /// 垂直卷动模式下，由列表直接上报哪一项在视口顶部，精确无误差。
  void _handlePositions() {
    if (_settings.layout != ComicPageLayout.verticalScroll) return;
    if (_draggingSlider) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    ItemPosition? best;
    for (final position in positions) {
      if (position.itemTrailingEdge <= 0 || position.itemLeadingEdge >= 1) {
        continue;
      }
      if (best == null || position.itemLeadingEdge < best.itemLeadingEdge) {
        best = position;
      }
    }
    final index = best?.index;
    if (index != null && index != _currentIndex.value) {
      _currentIndex.value = index;
      _scheduleSave();
    }
  }

  void _handleScroll() {
    if (_spreads.isEmpty) return;
    if (_settings.layout == ComicPageLayout.verticalScroll) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final int index;
    switch (_settings.layout) {
      case ComicPageLayout.horizontalScroll:
        final width = MediaQuery.of(context).size.width;
        if (width <= 0) return;
        index = (position.pixels / width)
            .round()
            .clamp(0, _spreads.length - 1);
      case ComicPageLayout.page:
      case ComicPageLayout.verticalScroll:
        return;
    }
    if (index != _currentIndex.value) {
      _currentIndex.value = index;
      _scheduleSave();
    }
  }

  void _goTo(int index) {
    if (_spreads.isEmpty) return;
    final target = index.clamp(0, _spreads.length - 1);
    if (_settings.layout == ComicPageLayout.page) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      _jumpTo(target);
    }
    if (target != _currentIndex.value) {
      _currentIndex.value = target;
      _scheduleSave();
    }
  }

  void _nextPage() => _goTo(_currentIndex.value + 1);

  void _previousPage() => _goTo(_currentIndex.value - 1);

  // ---------------------------------------------------------------- 进度

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveProgress);
  }

  Future<void> _saveProgress() async {
    final bookId = widget.book.id;
    if (bookId == null || _images.isEmpty) return;
    final logical = _currentLogicalPage;
    final progress = (logical + 1) / _images.length;
    try {
      await _dao.updateBookProgress(
        bookId,
        logical,
        readingProgress: progress.clamp(0.0, 1.0).toDouble(),
      );
    } catch (_) {
      // 进度保存失败不打断阅读。
    }
  }

  // ---------------------------------------------------------- 自动翻页

  void _restartAutoTurn() {
    _autoTurnTimer?.cancel();
    if (!_settings.autoTurn) return;
    _autoTurnTimer = Timer.periodic(
      Duration(seconds: _settings.autoTurnSeconds.clamp(2, 60).toInt()),
      (_) {
        if (!mounted) return;
        if (_currentIndex.value >= _spreads.length - 1) {
          _autoTurnTimer?.cancel();
          return;
        }
        _nextPage();
      },
    );
  }

  // ---------------------------------------------------------------- 设置

  Future<void> _applySettings(ComicViewSettings next) async {
    final needsRebuild =
        next.layout != _settings.layout ||
        next.splitDoublePage != _settings.splitDoublePage ||
        next.direction != _settings.direction ||
        next.fitMode != _settings.fitMode ||
        next.blankFirstPage != _settings.blankFirstPage;
    final anchorLogical = _currentLogicalPage;
    final autoTurnChanged =
        next.autoTurn != _settings.autoTurn ||
        next.autoTurnSeconds != _settings.autoTurnSeconds;

    if (next.splitDoublePage && _aspects.isEmpty) {
      _aspects = await ComicPageComposer.probeAspects(_images);
    }

    setState(() {
      _settings = next;
      if (needsRebuild) {
        _rebuildSpreads();
        _currentIndex.value = _indexForLogicalPage(anchorLogical);
      }
    });
    await _settingsStore.save(next);
    if (needsRebuild) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpTo(_currentIndex.value),
      );
    }
    if (autoTurnChanged) _restartAutoTurn();
    if (next.cropBorders) _ensureCropDetected(_currentLogicalPage);
  }

  // ---------------------------------------------------------------- 白边

  void _ensureCropDetected(int logicalPage) {
    if (!_settings.cropBorders) return;
    if (logicalPage < 0 || logicalPage >= _images.length) return;
    if (_cropRects.containsKey(logicalPage) ||
        _cropPending.contains(logicalPage)) {
      return;
    }
    _cropPending.add(logicalPage);
    _detectCrop(_images[logicalPage]).then((rect) {
      _cropPending.remove(logicalPage);
      if (!mounted) return;
      setState(() => _cropRects[logicalPage] = rect);
    });
  }

  /// 按需探测单页真实宽高比，供变高列表计算正确高度。
  void _ensureAspect(String? path) {
    if (path == null) return;
    if (_aspects.containsKey(path) || _aspectPending.contains(path)) return;
    _aspectPending.add(path);
    ComicPageComposer.probeAspects(<String>[path]).then((probed) {
      _aspectPending.remove(path);
      if (!mounted || probed.isEmpty) return;
      setState(() {
        _aspects = <String, double>{..._aspects, ...probed};
      });
    });
  }

  Future<Rect?> _detectCrop(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 360);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final rect = await ComicBorderCropper.detect(image);
      image.dispose();
      codec.dispose();
      return rect;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _screenWidth = media.size.width;
    final viewport =
        media.size.height - media.padding.top - media.padding.bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _spreads.isEmpty
          ? _buildEmpty()
          : _buildContent(viewport),
    );
  }

  Widget _buildContent(double viewport) {
    return Stack(
      children: [
        Positioned.fill(
          child: switch (_settings.layout) {
            ComicPageLayout.page => _buildHorizontal(),
            ComicPageLayout.horizontalScroll => _buildHorizontalScroll(),
            ComicPageLayout.verticalScroll => _buildVertical(viewport),
          },
        ),
        // 过滤蓝光：琥珀色蒙版；背光控制：黑色蒙版压暗整体。
        if (_settings.blueLightFilter > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: const Color(0xFFFF8A00).withValues(
                  alpha: (_settings.blueLightFilter / 100 * 0.30).clamp(
                    0.0,
                    0.30,
                  ),
                ),
              ),
            ),
          ),
        if (_settings.backlight < 100)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(
                  alpha: ((100 - _settings.backlight) / 100 * 0.72).clamp(
                    0.0,
                    0.72,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _handleTap,
            child: const SizedBox.expand(),
          ),
        ),
        if (_controlsVisible) _buildTopBar(),
        if (_controlsVisible) _buildBottomBar(),
      ],
    );
  }

  void _handleTap(TapUpDetails details) {
    final width = context.size?.width ?? 0;
    if (width <= 0 || !_settings.tapToTurn) {
      setState(() => _controlsVisible = !_controlsVisible);
      return;
    }
    final dx = details.localPosition.dx;
    // 日漫从右往左读，左侧是下一页；其余方向右侧是下一页。
    final nextOnLeft = _settings.direction.reversed;
    if (dx < width * 0.33) {
      if (nextOnLeft) {
        _nextPage();
      } else {
        _previousPage();
      }
      return;
    }
    if (dx > width * 0.67) {
      if (nextOnLeft) {
        _previousPage();
      } else {
        _nextPage();
      }
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
  }

  Widget _buildVertical(double viewport) {
    if (_usesFitWidthList) {
      // 不给项指定高度：由图片按自身比例撑开，杜绝估算比例造成的黑缝。
      // 用 ScrollablePositionedList：支持按页码精确跳转，
      // 高度仍由 _heightOf 固定，不会因图片加载而变。
      return ScrollablePositionedList.builder(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        itemCount: _spreads.length,
        itemBuilder: (context, index) => SizedBox(
          height: _heightOf(index),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: _settings.pageGap / 2),
            child: _buildSpread(index),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _spreads.length,
      itemExtent: viewport,
      itemBuilder: (context, index) => _buildSpread(index),
    );
  }

  Widget _buildHorizontal() {
    return PageView.builder(
      controller: _pageController,
      reverse: _settings.direction.reversed,
      itemCount: _spreads.length,
      onPageChanged: (index) {
        if (index != _currentIndex.value) {
          _currentIndex.value = index;
          _scheduleSave();
        }
      },
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(horizontal: _settings.pageGap / 2),
        child: _buildSpread(index),
      ),
    );
  }

  /// 水平卷动模式：一页一屏横向连续滚动。
  Widget _buildHorizontalScroll() {
    final width = MediaQuery.of(context).size.width;
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      reverse: _settings.direction.reversed,
      itemCount: _spreads.length,
      itemBuilder: (context, index) => SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _settings.pageGap / 2),
          child: _buildSpread(index),
        ),
      ),
    );
  }

  Widget _buildSpread(int index) {
    if (index < 0 || index >= _spreads.length) {
      return const SizedBox.shrink();
    }
    final spread = _spreads[index];
    if (spread.left == null && spread.right == null) {
      // 空白封里。
      return const ColoredBox(color: Colors.black);
    }
    _ensureCropDetected(spread.logicalPage);
    _ensureAspect(spread.left?.imagePath);
    _ensureAspect(spread.right?.imagePath);
    final left = spread.left;
    final right = spread.right;
    if (left != null) _ensureCropDetected(left.logicalPage);
    if (right != null) _ensureCropDetected(right.logicalPage);

    // 单页直接返回，让外层列表依据图片高度自适应。
    if (left != null && right == null) return _buildFrame(left);
    final children = <Widget>[];
    if (left != null) children.add(Expanded(child: _buildFrame(left)));
    if (right != null) children.add(Expanded(child: _buildFrame(right)));
    return Row(children: children);
  }

  Widget _buildFrame(ComicFrame frame) {
    // 高度计算与绘制共用同一份裁剪结果，避免比例不一致导致变形。
    final src = _effectiveSrc(frame);

    final matrix = _settings.hasColorAdjust
        ? ComicColorMatrix.fromSettings(_settings)
        : null;

    final needsCropPaint =
        src != ComicPageComposer.fullRect ||
        _settings.cropBorders ||
        _settings.manualCrop > 0;

    // 解码宽度按实际显示宽度取，避免为长条图分配过大的位图造成滚动卡顿。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((_screenWidth > 0 ? _screenWidth : 400) * dpr * 0.85)
        .round()
        .clamp(360, 1200);

    if (!needsCropPaint) {
      final plainFit = _usesFitWidthList ? BoxFit.fill : _boxFitForMode();
      Widget plain = Image.file(
        File(frame.imagePath),
        fit: plainFit,
        width: double.infinity,
        height: _usesFitWidthList ? double.infinity : null,
        cacheWidth: cacheWidth,
        // 低质量插值，滚动时明显更顺；图片本身尺寸已按屏宽解码，观感无损。
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
      if (matrix != null) {
        plain = ColorFiltered(
          colorFilter: ColorFilter.matrix(matrix),
          child: plain,
        );
      }
      return RepaintBoundary(child: plain);
    }

    // 需要裁剪时走画布：先取解码后的图。
    final image = _imageCache.get(frame.imagePath);
    if (image == null) {
      _imageCache.load(frame.imagePath).then((_) {
        if (mounted) setState(() {});
      });
      return const SizedBox.expand();
    }

    final croppedAspect = _displayAspect(frame);
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: croppedAspect,
        child: ClipRect(
          child: CustomPaint(
            painter: _ComicFramePainter(
              image: image,
              src: src,
              matrix: matrix,
              fit: BoxFit.fill,
              blur: _settings.blur,
            ),
            willChange: false,
          ),
        ),
      ),
    );
  }

  BoxFit _boxFitForMode() => switch (_settings.fitMode) {
    ComicFitMode.fitWidth => BoxFit.fitWidth,
    ComicFitMode.fitHeight => BoxFit.fitHeight,
    ComicFitMode.contain => BoxFit.contain,
  };

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_size_select_actual_outlined,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到图片页',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _currentIndex,
              builder: (context, index, _) {
                // 与底部页码共用同一套数字，避免出现 234/1273 与 235/1274 不一致。
                final current = _spreads.isEmpty
                    ? 0
                    : index.clamp(0, _spreads.length - 1);
                return Text(
                  '${current + 1} / ${_spreads.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '菜单',
            icon: const Icon(Icons.menu_rounded),
            onPressed: _showSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final last = _spreads.length - 1;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条：可拖动快速跳页；页码浮层照旧保留。
            if (_settings.showProgressBar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ValueListenableBuilder<int>(
                  valueListenable: _currentIndex,
                  builder: (context, index, _) => SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: const Color(0x55FFFFFF),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: index.toDouble().clamp(
                        0.0,
                        last > 0 ? last.toDouble() : 1.0,
                      ).toDouble(),
                      max: last > 1 ? last.toDouble() : 1.0,
                      onChangeStart: (_) => _draggingSlider = true,
                      // 拖动过程中只更新页码显示，不做实际跳转，避免与滚动回调互相抢。
                      onChanged: (value) {
                        _currentIndex.value = value.round().clamp(0, last);
                      },
                      onChangeEnd: (value) {
                        _draggingSlider = false;
                        final target = value.round().clamp(0, last);
                        _currentIndex.value = target;
                        _jumpTo(target);
                        _scheduleSave();
                      },
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pagePill(Icons.chevron_left_rounded, _previousPage),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentIndex,
                      builder: (context, index, _) => Text(
                        '${index + 1} / ${_spreads.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pagePill(Icons.chevron_right_rounded, _nextPage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagePill(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ------------------------------------------------------------ 菜单面板

  void _leaveReader() {
    // 先关菜单面板，再退出阅读页。
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    if (mounted && navigator.canPop()) navigator.pop();
  }

  Future<void> _deleteCurrentBook() async {
    final bookId = widget.book.id;
    if (bookId != null) {
      try {
        await _dao.deleteBook(bookId);
      } catch (_) {
        // 删除失败也退出，避免卡在阅读页。
      }
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _showSettings() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) => ComicMenuPanel(
        settings: _settings,
        pageCount: _images.length,
        spreadCount: _spreads.length,
        currentLogicalPage: _currentLogicalPage,
        imagePaths: _images,
        bookTitle: widget.book.title,
        bookPath: widget.book.filePath,
        onSettingsChanged: (next) => unawaited(_applySettings(next)),
        onJumpToPage: (page) {
          if (_images.isEmpty) return;
          final target = page.clamp(0, _images.length - 1);
          _goTo(_indexForLogicalPage(target));
        },
        onOpenLibrary: _leaveReader,
        onImportFile: _leaveReader,
        onDeleteBook: _deleteCurrentBook,
      ),
    );
  }
}

/// 漫画画面绘制器：按归一化 src 区域把图片画进给定尺寸。
class _ComicFramePainter extends CustomPainter {
  const _ComicFramePainter({
    required this.image,
    required this.src,
    required this.matrix,
    required this.fit,
    required this.blur,
  });

  final ui.Image image;
  final Rect src;
  final List<double>? matrix;
  final BoxFit fit;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final srcPixels = Rect.fromLTRB(
      (src.left * imageWidth).clamp(0.0, imageWidth),
      (src.top * imageHeight).clamp(0.0, imageHeight),
      (src.right * imageWidth).clamp(0.0, imageWidth),
      (src.bottom * imageHeight).clamp(0.0, imageHeight),
    );
    if (srcPixels.width <= 0 || srcPixels.height <= 0) return;

    final fitted = applyBoxFit(fit, srcPixels.size, size);
    // 符合宽度时顶部对齐：比例估小的情况下留白落在下方，符合长条漫阅读习惯。
    final alignment = fit == BoxFit.fitWidth
        ? Alignment.topCenter
        : Alignment.center;
    final destination = alignment.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final paint = Paint()..filterQuality = FilterQuality.low;
    final adjustment = matrix;
    if (adjustment != null && adjustment.length == 20) {
      paint.colorFilter = ColorFilter.matrix(adjustment);
    }
    if (blur > 0) {
      paint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    }
    canvas.drawImageRect(image, srcPixels, destination, paint);
  }

  @override
  bool shouldRepaint(_ComicFramePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.src != src ||
      oldDelegate.fit != fit ||
      oldDelegate.blur != blur ||
      !listEquals(oldDelegate.matrix, matrix);
}

/// 漫画页面图片缓存：保留最近若干张已解码图片，避免滚动时反复解码。
class _ComicImageCache {
  static const int _maxEntries = 8;

  final Map<String, ui.Image> _ready = <String, ui.Image>{};
  final Set<String> _pending = <String>{};

  ui.Image? get(String path) => _ready[path];

  Future<void> load(String path) async {
    if (_ready.containsKey(path) || _pending.contains(path)) return;
    _pending.add(path);
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
      final frame = await codec.getNextFrame();
      codec.dispose();
      _ready[path] = frame.image;
      while (_ready.length > _maxEntries) {
        final key = _ready.keys.first;
        _ready.remove(key)?.dispose();
      }
    } catch (_) {
      // 单张解码失败不影响其它页。
    } finally {
      _pending.remove(path);
    }
  }

  void dispose() {
    for (final image in _ready.values) {
      image.dispose();
    }
    _ready.clear();
    _pending.clear();
  }
}
