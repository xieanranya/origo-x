// 文件说明：漫画阅读页。支持垂直连贯 / 水平左滑 / 水平右滑三种翻页方向，
// 自动裁白边，以及对齐 Perfect Viewer 的颜色校正（亮度/对比度/饱和度/色相/Gamma/反色/灰度）。
// 技术要点：颜色校验收敛成单个 4x5 矩阵由 GPU 一次合成；白边在小图上检测后按比例换算，避免逐页解大图。
import 'dart:async';
import 'dart:io';
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
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final Map<int, Rect?> _cropRects = <int, Rect?>{};
  final Set<int> _cropPending = <int>{};

  List<String> _pages = const <String>[];
  ComicViewSettings _settings = const ComicViewSettings();
  bool _loading = true;
  bool _controlsVisible = true;
  double _viewport = 0;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _currentPage.dispose();
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
      _pages = files.map((file) => file.path).toList(growable: false);
    }
    final start = widget.book.currentPage.clamp(
      0,
      _pages.isEmpty ? 0 : _pages.length - 1,
    );
    _currentPage.value = start;
    if (!mounted) return;
    setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(start));
  }

  // ---------------------------------------------------------------- 翻页

  void _jumpTo(int index) {
    if (_pages.isEmpty) return;
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
    if (_viewport <= 0 || _pages.isEmpty) return;
    final offset = _scrollController.position.pixels + _viewport * 0.5;
    final index = (offset / _viewport).floor().clamp(0, _pages.length - 1);
    if (index != _currentPage.value) {
      _currentPage.value = index;
      _scheduleSave();
    }
  }

  void _goToPage(int index) {
    if (_pages.isEmpty) return;
    final target = index.clamp(0, _pages.length - 1);
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
    if (target != _currentPage.value) {
      _currentPage.value = target;
      _scheduleSave();
    }
  }

  // ---------------------------------------------------------------- 进度

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveProgress);
  }

  Future<void> _saveProgress() async {
    final bookId = widget.book.id;
    if (bookId == null || _pages.isEmpty) return;
    final progress = (_currentPage.value + 1) / _pages.length;
    try {
      await _dao.updateBookProgress(
        bookId,
        _currentPage.value,
        readingProgress: progress,
      );
    } catch (_) {
      // 进度保存失败不打断阅读。
    }
  }

  Future<void> _applySettings(ComicViewSettings next) async {
    final directionChanged = next.direction != _settings.direction;
    final current = _currentPage.value;
    setState(() => _settings = next);
    await _settingsStore.save(next);
    if (directionChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(current));
    }
  }

  // ---------------------------------------------------------------- 白边

  void _ensureCropDetected(int index) {
    if (!_settings.cropBorders) return;
    if (_cropRects.containsKey(index) || _cropPending.contains(index)) return;
    if (index < 0 || index >= _pages.length) return;
    _cropPending.add(index);
    _detectCrop(_pages[index]).then((rect) {
      _cropPending.remove(index);
      if (!mounted) return;
      setState(() => _cropRects[index] = rect);
    });
  }

  Future<Rect?> _detectCrop(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      // 用缩略尺寸检测，比例与全图一致，几百毫秒内完成。
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
          : _pages.isEmpty
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
            onTap: () => setState(() => _controlsVisible = !_controlsVisible),
            child: const SizedBox.expand(),
          ),
        ),
        if (_controlsVisible) _buildTopBar(),
        if (_controlsVisible) _buildBottomBar(),
      ],
    );
  }

  Widget _buildVertical(double viewport) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _pages.length,
      itemExtent: viewport,
      itemBuilder: (context, index) => _buildPage(index),
    );
  }

  Widget _buildHorizontal() {
    return PageView.builder(
      controller: _pageController,
      // 日漫方向：向右滑进入下一页。
      reverse: _settings.direction.reversed,
      itemCount: _pages.length,
      onPageChanged: (index) {
        if (index != _currentPage.value) {
          _currentPage.value = index;
          _scheduleSave();
        }
      },
      itemBuilder: (context, index) => _buildPage(index),
    );
  }

  Widget _buildPage(int index) {
    _ensureCropDetected(index);
    final rect = _settings.cropBorders ? _cropRects[index] : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget image = Image.file(
          File(_pages[index]),
          fit: BoxFit.contain,
          cacheWidth: 1440,
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 48,
          ),
        );
        if (_settings.hasColorAdjust) {
          image = ColorFiltered(
            colorFilter: ColorFilter.matrix(
              ComicColorMatrix.fromSettings(_settings),
            ),
            child: image,
          );
        }
        if (rect == null) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(child: image),
          );
        }
        // 把内容区域放大到铺满，保持比例（取两个方向中较大的放大倍数）。
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final contentWidth = rect.width * width;
        final contentHeight = rect.height * height;
        if (contentWidth <= 0 || contentHeight <= 0) {
          return Center(child: image);
        }
        final scaleX = width / contentWidth;
        final scaleY = height / contentHeight;
        final scale = scaleX > scaleY ? scaleX : scaleY;
        final offsetX = ((rect.left + rect.right) / 2 - 0.5) * width * scale;
        final offsetY = ((rect.top + rect.bottom) / 2 - 0.5) * height * scale;
        return ClipRect(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(-offsetX, -offsetY)
              ..scale(scale, scale),
            child: Center(child: image),
          ),
        );
      },
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
              valueListenable: _currentPage,
              builder: (context, current, _) => Text(
                '${current + 1} / ${_pages.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '显示设置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
                valueListenable: _currentPage,
                builder: (context, current, _) => Slider(
                  value: current.toDouble().clamp(
                    0.0,
                    (_pages.length - 1) > 0
                        ? (_pages.length - 1).toDouble()
                        : 1.0,
                  ),
                  max: (_pages.length - 1) > 1
                      ? (_pages.length - 1).toDouble()
                      : 1.0,
                  onChanged: (value) => _goToPage(value.round()),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    color: Colors.white,
                    onPressed: () => _goToPage(_currentPage.value - 1),
                  ),
                  Expanded(
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _currentPage,
                        builder: (context, current, _) => Text(
                          '${current + 1} / ${_pages.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    color: Colors.white,
                    onPressed: () => _goToPage(_currentPage.value + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 设置面板

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
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ],
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
                  const SizedBox(height: 4),
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _settings.cropBorders,
                    onChanged: (value) {
                      update(_settings.copyWith(cropBorders: value));
                      if (value) {
                        _cropRects.clear();
                        _ensureCropDetected(_currentPage.value);
                      }
                    },
                    title: Text('裁掉白边', style: textStyle),
                    subtitle: Text(
                      '自动识别页面四周空白并放大画面',
                      style: textStyle.copyWith(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
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
                    onChanged: (v) => update(_settings.copyWith(gamma: v / 100)),
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
