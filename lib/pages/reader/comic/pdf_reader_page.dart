// 文件说明：PDF 漫画/书刊阅读页，基于 pdfx（iOS 走 CGPDFPage，安卓走 PdfRenderer）。
// 技术要点：打开文档后回填真实页数到 books 表，翻页进度与文本阅读共用同一字段。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../models/book.dart';
import '../../../services/books/book_dao.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  final BookDao _dao = BookDao();
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final ValueNotifier<int> _totalPages = ValueNotifier<int>(0);

  PdfController? _controller;
  bool _loading = true;
  String? _error;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _openDocument();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveProgress();
    _currentPage.dispose();
    _totalPages.dispose();
    super.dispose();
  }

  Future<void> _openDocument() async {
    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) {
        throw StateError('文件不存在');
      }
      final document = await PdfDocument.openFile(file.path);
      if (!mounted) return;
      final total = document.pagesCount;
      _totalPages.value = total;
      _currentPage.value = widget.book.currentPage.clamp(0, total - 1);
      _controller = PdfController(
        document: Future.value(document),
        initialPage: _currentPage.value + 1,
      );
      setState(() => _loading = false);
      // 回填真实页数，书架上显示的总数才准确。
      if (widget.book.id != null && widget.book.totalPages != total) {
        await _dao.updateBookTotalPages(widget.book.id!, total);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveProgress);
  }

  Future<void> _saveProgress() async {
    final bookId = widget.book.id;
    final total = _totalPages.value;
    if (bookId == null || total <= 0) return;
    final progress = (_currentPage.value + 1) / total;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
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
                '${current + 1} / ${_totalPages.value}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _controller == null
          ? const SizedBox.shrink()
          : PdfView(
              controller: _controller!,
              scrollDirection: Axis.vertical,
              onPageChanged: (page) {
                if (page != _currentPage.value) {
                  _currentPage.value = page;
                  _scheduleSave();
                }
              },
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? '打开失败',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
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
                  _totalPages.value > 0
                      ? (_totalPages.value - 1).toDouble()
                      : 1.0,
                ),
                max: _totalPages.value > 1
                    ? (_totalPages.value - 1).toDouble()
                    : 1.0,
                onChanged: (value) {
                  final page = value.round();
                  _currentPage.value = page;
                  _controller?.animateToPage(
                    page,
                    duration: _anim,
                    curve: Curves.easeOutCubic,
                  );
                  _scheduleSave();
                },
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  color: Colors.white,
                  onPressed: () => _controller?.previousPage(
                    duration: _anim,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentPage,
                      builder: (context, current, _) => Text(
                        '${current + 1} / ${_totalPages.value}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  color: Colors.white,
                  onPressed: () => _controller?.nextPage(
                    duration: _anim,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final Duration _anim = const Duration(milliseconds: 220);
}
