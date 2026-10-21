// 文件说明：漫画阅读页，能力对齐 Perfect Viewer。
// 支持：垂直连贯 / 水平左滑 / 水平右滑、双页扫描自动分割、双页跨页并排、
// 分屏放大、白边裁剪、颜色校正、自动翻页、点击分区翻页。
// 技术要点：源图先编排成「画面」，再配对成「屏」；每个画面按归一化 src 区域用
// Transform 放大铺满，颜色校验收敛为单个 4x5 矩阵交给 GPU。
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../models/book.dart';
import '../../../services/books/book_dao.dart';
import '../../../services/books/comic_archive_service.dart';
import '../../../services/reader/comic_view_settings.dart';

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
  final _ComicImageCache _imageCache = _ComicImageCache();

  List<String> _images = const <String>[];
  Map<String, double> _aspects = const <String, double>{};
  List<ComicFrame> _frames = const <ComicFrame>[];
  List<ComicSpread> _spreads = const <ComicSpread>[];
  ComicViewSettings _settings = const ComicViewSettings();
  bool _loading = true;
  bool _controlsVisible = true;
  double _viewport = 0;
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
    // 只有开启双页分割时才需要宽高比，避免几百页漫画白等一轮探测。
    _aspects = _settings.splitDoublePage
        ? await ComicPageComposer.probeAspects(_images)
        : <String, double>{};
    _rebuildSpreads();
    _currentIndex.value = _indexForLogicalPage(widget.book.currentPage);
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpTo(_currentIndex.value),
    );
    _restartAutoTurn();
  }

  // ---------------------------------------------------------- 页面编排

  void _rebuildSpreads() {
    _frames = ComicPageComposer.expandFrames(
      paths: _images,
      aspects: _aspects,
      settings: _settings,
    );
    _spreads = ComicPageComposer.composeSpreads(
      frames: _frames,
      settings: _settings,
    );
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

  // ---------------------------------------------------------------- 翻页

  void _jumpTo(int index) {
    if (_spreads.isEmpty) return;
    if (_settings.direction.isHorizontal) {
      if (_pageController.hasClients) _pageController.jumpToPage(index);
      return;
    }
    if (_scrollController.hasClients && _viewport > 0) {
      final target = (index * _viewport).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    }
  }

  void _handleScroll() {
    if (_settings.direction.isHorizontal) return;
    if (_viewport <= 0 || _spreads.isEmpty) return;
    final offset = _scrollController.position.pixels + _viewport * 0.5;
    final index = (offset / _viewport).floor().clamp(0, _spreads.length - 1);
    if (index != _currentIndex.value) {
      _currentIndex.value = index;
      _scheduleSave();
    }
  }

  void _goTo(int index) {
    if (_spreads.isEmpty) return;
    final target = index.clamp(0, _spreads.length - 1);
    if (_settings.direction.isHorizontal) {
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
        next.splitScreen != _settings.splitScreen ||
        next.direction != _settings.direction;
    final anchorLogical = _currentLogicalPage;
    final autoTurnChanged =
        next.autoTurn != _settings.autoTurn ||
        next.autoTurnSeconds != _settings.autoTurnSeconds;

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
    if (next.cropBorders) {
      _ensureCropDetected(_currentLogicalPage);
    }
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
          child: _settings.direction.isHorizontal
              ? _buildHorizontal()
              : _buildVertical(viewport),
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
      itemBuilder: (context, index) => _buildSpread(index),
    );
  }

  Widget _buildSpread(int index) {
    if (index < 0 || index >= _spreads.length) {
      return const SizedBox.shrink();
    }
    final spread = _spreads[index];
    _ensureCropDetected(spread.logicalPage);
    final left = spread.left;
    final right = spread.right;
    if (left != null) _ensureCropDetected(left.logicalPage);
    if (right != null) _ensureCropDetected(right.logicalPage);

    final children = <Widget>[];
    if (left != null) children.add(Expanded(child: _buildFrame(left)));
    if (right != null) children.add(Expanded(child: _buildFrame(right)));
    return Row(children: children);
  }

  Widget _buildFrame(ComicFrame frame) {
    // 合并「双页切分 / 分屏」的 src 与自动白边裁剪结果。
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

    final image = _imageCache.get(frame.imagePath);
    if (image == null) {
      _imageCache.load(frame.imagePath).then((_) {
        if (mounted) setState(() {});
      });
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final matrix = _settings.hasColorAdjust
        ? ComicColorMatrix.fromSettings(_settings)
        : null;
    return ClipRect(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _ComicFramePainter(
            image: image,
            src: src,
            matrix: matrix,
          ),
          isComplex: true,
          willChange: false,
        ),
      ),
    );
  }

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
            tooltip: '阅读设置',
            icon: const Icon(Icons.tune_rounded),
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
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _currentIndex,
                builder: (context, index, _) => Slider(
                  value: index.toDouble().clamp(
                    0.0,
                    last > 0 ? last.toDouble() : 1.0,
                  ).toDouble(),
                  max: last > 1 ? last.toDouble() : 1.0,
                  onChanged: (value) => _goTo(value.round()),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: Colors.white,
                    onPressed: _previousPage,
                  ),
                  Expanded(
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentIndex,
                        builder: (context, index, _) => Text(
                          '${index + 1} / ${_spreads.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: Colors.white,
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 设置面板

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15181A),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(ComicViewSettings next) {
            setSheet(() {});
            unawaited(_applySettings(next));
          }

          final textStyle = TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
          );

          Widget slider({
            required String label,
            required double value,
            required double min,
            required double max,
            required int divisions,
            required String valueLabel,
            required ValueChanged<double> onChanged,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: textStyle),
                    const Spacer(),
                    Text(valueLabel, style: textStyle.copyWith(fontSize: 12)),
                  ],
                ),
                Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ],
            );
          }

          Widget switchTile({
            required String title,
            required String subtitle,
            required bool value,
            required ValueChanged<bool> onChanged,
          }) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: value,
              onChanged: onChanged,
              title: Text(title, style: textStyle),
              subtitle: Text(
                subtitle,
                style: textStyle.copyWith(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '阅读设置',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => update(
                          _settings.copyWith(
                            brightness: 0,
                            contrast: 1,
                            saturation: 1,
                            hue: 0,
                            gamma: 1,
                            invert: false,
                            grayscale: false,
                          ),
                        ),
                        child: const Text('颜色复位'),
                      ),
                    ],
                  ),
                  Text(
                    '翻页方向',
                    style: textStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final direction in ComicPageDirection.values)
                        ChoiceChip(
                          label: Text(direction.label),
                          selected: _settings.direction == direction,
                          onSelected: (_) =>
                              update(_settings.copyWith(direction: direction)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '版面',
                    style: textStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final layout in ComicPageLayout.values)
                        ChoiceChip(
                          label: Text(layout.label),
                          selected: _settings.layout == layout,
                          onSelected: (_) =>
                              update(_settings.copyWith(layout: layout)),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  switchTile(
                    title: '自动分割双页',
                    subtitle: '横向宽图视为双页扫描，自动切成左右两页',
                    value: _settings.splitDoublePage,
                    onChanged: (value) =>
                        update(_settings.copyWith(splitDoublePage: value)),
                  ),
                  switchTile(
                    title: '分屏放大',
                    subtitle: '把一页横切成上下两半，小屏也能看清',
                    value: _settings.splitScreen,
                    onChanged: (value) =>
                        update(_settings.copyWith(splitScreen: value)),
                  ),
                  switchTile(
                    title: '裁掉白边',
                    subtitle: '自动识别四周空白并放大画面',
                    value: _settings.cropBorders,
                    onChanged: (value) =>
                        update(_settings.copyWith(cropBorders: value)),
                  ),
                  switchTile(
                    title: '点击翻页',
                    subtitle: '点屏幕左右区域翻页，中间显隐工具栏',
                    value: _settings.tapToTurn,
                    onChanged: (value) =>
                        update(_settings.copyWith(tapToTurn: value)),
                  ),
                  switchTile(
                    title: '自动翻页',
                    subtitle: '按设定间隔自动往后翻',
                    value: _settings.autoTurn,
                    onChanged: (value) =>
                        update(_settings.copyWith(autoTurn: value)),
                  ),
                  if (_settings.autoTurn)
                    slider(
                      label: '翻页间隔',
                      value: _settings.autoTurnSeconds.toDouble(),
                      min: 2,
                      max: 30,
                      divisions: 28,
                      valueLabel: '${_settings.autoTurnSeconds} 秒',
                      onChanged: (v) => update(
                        _settings.copyWith(autoTurnSeconds: v.round()),
                      ),
                    ),
                  const Divider(color: Colors.white24),
                  Text(
                    '颜色校正',
                    style: textStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  slider(
                    label: '亮度',
                    value: _settings.brightness,
                    min: -100,
                    max: 100,
                    divisions: 40,
                    valueLabel: _settings.brightness.round().toString(),
                    onChanged: (v) => update(_settings.copyWith(brightness: v)),
                  ),
                  slider(
                    label: '对比度',
                    value: _settings.contrast * 100,
                    min: 50,
                    max: 200,
                    divisions: 30,
                    valueLabel: '${(_settings.contrast * 100).round()}%',
                    onChanged: (v) =>
                        update(_settings.copyWith(contrast: v / 100)),
                  ),
                  slider(
                    label: '饱和度',
                    value: _settings.saturation * 100,
                    min: 0,
                    max: 200,
                    divisions: 40,
                    valueLabel: '${(_settings.saturation * 100).round()}%',
                    onChanged: (v) =>
                        update(_settings.copyWith(saturation: v / 100)),
                  ),
                  slider(
                    label: '色相',
                    value: _settings.hue,
                    min: -180,
                    max: 180,
                    divisions: 36,
                    valueLabel: '${_settings.hue.round()}°',
                    onChanged: (v) => update(_settings.copyWith(hue: v)),
                  ),
                  slider(
                    label: 'Gamma',
                    value: _settings.gamma * 100,
                    min: 50,
                    max: 200,
                    divisions: 30,
                    valueLabel: '${(_settings.gamma * 100).round()}%',
                    onChanged: (v) =>
                        update(_settings.copyWith(gamma: v / 100)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('反色'),
                        selected: _settings.invert,
                        onSelected: (value) =>
                            update(_settings.copyWith(invert: value)),
                      ),
                      FilterChip(
                        label: const Text('灰度'),
                        selected: _settings.grayscale,
                        onSelected: (value) =>
                            update(_settings.copyWith(grayscale: value)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 漫画画面绘制器：按归一化 src 区域把图片画进给定尺寸，保持比例并居中。
class _ComicFramePainter extends CustomPainter {
  const _ComicFramePainter({
    required this.image,
    required this.src,
    required this.matrix,
  });

  final ui.Image image;
  final Rect src;
  final List<double>? matrix;

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

    final fitted = applyBoxFit(BoxFit.contain, srcPixels.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final adjustment = matrix;
    if (adjustment != null && adjustment.length == 20) {
      paint.colorFilter = ColorFilter.matrix(adjustment);
    }
    canvas.drawImageRect(image, srcPixels, destination, paint);
  }

  @override
  bool shouldRepaint(_ComicFramePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.src != src ||
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
