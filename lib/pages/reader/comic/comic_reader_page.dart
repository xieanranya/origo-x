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
  double _viewport = 0;
  double _screenWidth = 0;
  /// 平均每屏高度，用于滚动时的 O(1) 页码估算。
  double _averageHeight = 0;
  Timer? _saveDebounce;
  Timer? _autoTurnTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _autoTurnTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
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
    // 宽高比只在需要裁剪/双页切分时才用到，且不阻塞首屏：
    // 先按兜底比例排版并立即显示，比例在后台补。
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

    // 预估平均高度（用兜底比例即可），滚动时据此 O(1) 估算页码。
    final width = _screenWidth > 0
        ? _screenWidth
        : MediaQuery.of(context).size.width;
    _averageHeight = _spreads.isEmpty ? 0 : width / 0.7;
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
  double _frameAspect(ComicFrame frame) {
    final image = _imageCache.get(frame.imagePath);
    final probed = _aspects[frame.imagePath];
    final fallback = frame.imageAspect > 0 ? frame.imageAspect : 0.7;
    final base = image != null && image.height > 0
        ? image.width / image.height
        : (probed != null && probed > 0 ? probed : fallback);
    final widthRatio = frame.src.width <= 0 ? 1.0 : frame.src.width;
    final heightRatio = frame.src.height <= 0 ? 1.0 : frame.src.height;
    return base * (widthRatio / heightRatio);
  }

  /// 一屏的宽高比：双页并排时两页宽度相加。
  double _spreadAspect(ComicSpread spread) {
    final left = spread.left;
    final right = spread.right;
    if (left != null && right != null) {
      return _frameAspect(left) + _frameAspect(right);
    }
    final only = left ?? right;
    return only == null ? 1.0 : _frameAspect(only);
  }

  /// 某一屏在变高列表里的高度：屏宽 ÷ 该屏真实比例。
  double _heightOf(int index) {
    if (index < 0 || index >= _spreads.length) return 0;
    final width = _screenWidth > 0
        ? _screenWidth
        : MediaQuery.of(context).size.width;
    final aspect = _spreadAspect(_spreads[index]);
    // 比例异常时按 0.7 兜底，避免出现 0 高度的空项。
    final safeAspect = aspect > 0.05 ? aspect : 0.7;
    return width / safeAspect;
  }

  double _offsetOf(int index) {
    var sum = 0.0;
    for (var i = 0; i < index && i < _spreads.length; i++) {
      sum += _heightOf(i);
    }
    return sum;
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
        if (_scrollController.hasClients) {
          final target = _offsetOf(index).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(target);
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

  void _handleScroll() {
    if (_spreads.isEmpty || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final int index;
    switch (_settings.layout) {
      case ComicPageLayout.verticalScroll:
        // 用平均高度做 O(1) 估算，避免每帧遍历上千页。
        if (_averageHeight <= 0) return;
        final ratio = (position.pixels + _viewport * 0.5) / _averageHeight;
        index = ratio.round().clamp(0, _spreads.length - 1);
      case ComicPageLayout.horizontalScroll:
        final width = MediaQuery.of(context).size.width;
        if (width <= 0) return;
        index = (position.pixels / width)
            .round()
            .clamp(0, _spreads.length - 1);
      case ComicPageLayout.page:
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
      setState(() => _aspects = <String, double>{..._aspects, ...probed});
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
    _viewport = viewport;
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
      return ListView.builder(
        controller: _scrollController,
        itemCount: _spreads.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.symmetric(vertical: _settings.pageGap / 2),
          child: _buildSpread(index),
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
    // 合并「双页切分」的 src 与自动白边侦测结果。
    var src = frame.src;
    if (_settings.cropBorders) {
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

    // 手工裁切：四边等比内缩。
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

    final matrix = _settings.hasColorAdjust
        ? ComicColorMatrix.fromSettings(_settings)
        : null;

    // 不需要裁剪（无白边裁剪 / 无手工裁切 / 未切分双页）时，直接用 Image 渲染：
    // 宽度铺满、高度由图片自身比例决定；加载态由 Image 自己处理，
    // 不能在这里放小尺寸占位——否则一屏会挤出几十个占位、同时触发几十张解码。
    final needsCropPaint =
        src != ComicPageComposer.fullRect ||
        _settings.cropBorders ||
        _settings.manualCrop > 0;
    if (!needsCropPaint) {
      final placeholderHeight = MediaQuery.of(context).size.height;
      Widget plain = Image.file(
        File(frame.imagePath),
        fit: BoxFit.fitWidth,
        width: double.infinity,
        cacheWidth: 1600,
        // 解码完成前高度为 0，会让整屏图片挤在一起并同时发起解码；
        // 这里给接近一屏的占位，保证一屏只有一两项在加载。
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          // 与 PV 一致：未解码时只是留白，不显示转圈。
          return SizedBox(
            height: placeholderHeight,
            child: const ColoredBox(color: Colors.black),
          );
        },
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
      return plain;
    }

    // 需要裁剪时走画布：先取解码后的图。
    final image = _imageCache.get(frame.imagePath);
    if (image == null) {
      _imageCache.load(frame.imagePath).then((_) {
        if (mounted) setState(() {});
      });
      // 占位必须接近整屏高度，否则一屏会堆下几十个占位并同时发起解码。
      final placeholderHeight = MediaQuery.of(context).size.height * 0.6;
      return SizedBox(
        height: placeholderHeight,
        child: const ColoredBox(color: Colors.black),
      );
    }

    final fit = _usesFitWidthList ? BoxFit.fitWidth : _boxFitForMode();
    final aspect = _frameAspect(frame);
    final safeAspect = aspect > 0.05 ? aspect : 0.7;
    return AspectRatio(
      aspectRatio: safeAspect,
      child: ClipRect(
        child: CustomPaint(
          painter: _ComicFramePainter(
            image: image,
            src: src,
            matrix: matrix,
            fit: fit,
            blur: _settings.blur,
          ),
          isComplex: true,
          willChange: false,
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
                final logical = _spreads.isEmpty
                    ? 0
                    : _spreads[index.clamp(0, _spreads.length - 1)]
                          .logicalPage;
                return Text(
                  '${logical + 1} / ${_images.length}',
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
                      onChanged: (value) => _goTo(value.round()),
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
    final paint = Paint()..filterQuality = FilterQuality.medium;
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
