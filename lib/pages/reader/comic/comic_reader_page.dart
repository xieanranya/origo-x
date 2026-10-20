// 文件说明：漫画阅读页。图片流呈现，支持连续滚动（Webtoon）与单页翻页两种模式。
// 技术要点：图片按 cacheWidth 限制解码宽度避免 OOM；进度写入 books 表，与文本同库。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/book.dart';
import '../../services/books/book_dao.dart';
import '../../services/books/comic_archive_service.dart';

/// 漫画阅读模式。
enum ComicReadingMode { continuous, singlePage }

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  final BookDao _dao = BookDao();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);

  List<String> _pages = const <String>[];
  bool _loading = true;
  bool _controlsVisible = true;
  ComicReadingMode _mode = ComicReadingMode.continuous;
  double _viewport = 0;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadPages();
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

  Future<void> _loadPages() async {
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

  void _jumpTo(int index) {
    if (_pages.isEmpty) return;
    switch (_mode) {
      case ComicReadingMode.continuous:
        if (_scrollController.hasClients && _viewport > 0) {
          final target = (index * _viewport).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(target);
        }
      case ComicReadingMode.singlePage:
        if (_pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
    }
  }

  void _handleScroll() {
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
    if (_mode == ComicReadingMode.singlePage &&
        _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _jumpTo(target);
    }
    if (target != _currentPage.value) {
      _currentPage.value = target;
      _scheduleSave();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewport = media.size.height - media.padding.top - media.padding.bottom;
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
          child: _mode == ComicReadingMode.continuous
              ? _buildContinuous(viewport)
              : _buildSinglePage(),
        ),
        // 中央点击区切换控件显隐；放在控件层之下。
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

  Widget _buildContinuous(double viewport) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _pages.length,
      itemExtent: viewport,
      itemBuilder: (context, index) => _buildPage(index),
    );
  }

  Widget _buildSinglePage() {
    return PageView.builder(
      controller: _pageController,
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
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.file(
          File(_pages[index]),
          fit: BoxFit.contain,
          // 限制解码宽度，防止超大原图把内存吃光。
          cacheWidth: 1440,
          errorBuilder: (_, _, _) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_size_select_actual_outlined,
              color: Colors.white54, size: 48),
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
            tooltip: _mode == ComicReadingMode.continuous ? '切到单页' : '切到连续滚动',
            icon: Icon(
              _mode == ComicReadingMode.continuous
                  ? Icons.photo_size_select_large_outlined
                  : Icons.view_day_outlined,
            ),
            onPressed: () {
              final current = _currentPage.value;
              setState(() {
                _mode = _mode == ComicReadingMode.continuous
                    ? ComicReadingMode.singlePage
                    : ComicReadingMode.continuous;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(current));
            },
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
                  value: current
                      .toDouble()
                      .clamp(0, (_pages.length - 1).toDouble()),
                  max: (_pages.length - 1).toDouble().clamp(1, 1 << 30),
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
                      child: Text(
                        '${_currentPage.value + 1} / ${_pages.length}',
                        style: const TextStyle(color: Colors.white),
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
}
