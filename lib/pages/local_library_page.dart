import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../services/books/book_dao.dart';
import '../services/books/book_import_models.dart';
import '../services/books/book_import_service.dart';
import '../services/books/comic_archive_service.dart';
import '../services/books/cover_generator_service.dart';
import '../services/core/theme_notifier.dart';
import '../services/reading/reading_stats_dao.dart';
import 'reader/comic/comic_reader_page.dart';
import 'reader/native/native_reader_page.dart';

/// 书架布局模式。
enum ShelfLayout { list, grid }

/// 书架排序方式。
enum ShelfSort {
  recentRead, // 最近阅读
  importDate, // 导入时间
  title, // 书名
  progress, // 阅读进度
}

/// 书架筛选方式。
enum ShelfFilter {
  all, // 全部
  unread, // 未读
  reading, // 在读
  finished, // 读完
}

class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({
    super.key,
    this.booksLoader,
    this.onOpenBook,
    this.onImport,
  });

  final Future<List<Book>> Function()? booksLoader;
  final Future<void> Function(Book)? onOpenBook;
  final Future<void> Function()? onImport;

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  final _booksDao = BookDao();
  late Future<List<Book>> _books;
  bool _importing = false;
  String _query = '';
  ShelfLayout _layout = ShelfLayout.list;
  ShelfSort _sort = ShelfSort.importDate;
  ShelfFilter _filter = ShelfFilter.all;

  static const _prefLayoutKey = 'shelf_layout_mode';
  static const _prefSortKey = 'shelf_sort_mode';

  @override
  void initState() {
    super.initState();
    _books = _loadBooks();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    // 测试环境没有平台通道，getInstance 会抛/挂：兜底用默认布局与排序
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _layout = prefs.getString(_prefLayoutKey) == 'grid'
            ? ShelfLayout.grid
            : ShelfLayout.list;
        final sortName = prefs.getString(_prefSortKey);
        _sort = ShelfSort.values.firstWhere(
          (value) => value.name == sortName,
          orElse: () => ShelfSort.importDate,
        );
      });
    } catch (_) {
      // 保持默认值
    }
  }

  Future<void> _saveLayout(ShelfLayout layout) async {
    setState(() => _layout = layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLayoutKey, layout.name);
  }

  Future<void> _saveSort(ShelfSort sort) async {
    setState(() => _sort = sort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSortKey, sort.name);
  }

  Future<List<Book>> _loadBooks() =>
      (widget.booksLoader ?? _booksDao.getAllBooks)();

  void _reload() {
    if (mounted) {
      final books = _loadBooks();
      setState(() {
        _books = books;
      });
    }
  }

  bool get _chinese => Localizations.localeOf(context).languageCode == 'zh';
  String _text(String chinese, String english) => _chinese ? chinese : english;

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      if (widget.onImport != null) {
        await widget.onImport!();
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['txt', 'epub', 'cbz', 'zip'],
          allowMultiple: true,
          withData: kIsWeb,
        );
        if (result == null) return;
        final importer = BookImportService();
        var imported = 0;
        var skipped = 0;
        for (final file in result.files) {
          // 漫画压缩包走解压导入，和 TXT / EPUB 不是一条链路。
          final localPath = file.path;
          if (localPath != null &&
              ComicArchiveService.isComicArchive(
                p.extension(localPath),
              )) {
            try {
              final book = await ComicArchiveService.importComic(
                File(localPath),
              );
              if (book == null) {
                skipped++;
              } else {
                imported++;
              }
            } catch (error) {
              skipped++;
              debugPrint('漫画导入失败 ${file.name}: $error');
            }
            continue;
          }
          final source = BookImportSource(
            id: 'picker:${file.name}:${DateTime.now().microsecondsSinceEpoch}',
            kind: BookImportSourceKind.filePicker,
            ownership: BookImportOwnership.externalCopy,
            displayName: file.name,
            extension: file.extension ?? '',
            locator: file.path ?? file.name,
            localPath: file.path,
            sizeBytes: file.size,
            bytes: file.bytes,
          );
          await importer.importFile(source);
          imported++;
        }
        _message(
          skipped == 0
              ? _text('已处理 $imported 本书', 'Processed $imported books')
              : _text(
                  '已导入 $imported 本，$skipped 个文件没有可用图片',
                  'Imported $imported, $skipped file(s) had no pages',
                ),
        );
      }
      _reload();
    } catch (error) {
      _message(_text('导入失败：$error', 'Import failed: $error'));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(Book book) async {
    // 漫画走图片阅读页，与文本阅读器分开。
    if (ComicArchiveService.isComicArchive(book.format)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ComicReaderPage(book: book)),
      );
      _reload();
      return;
    }
    if (widget.onOpenBook != null) {
      await widget.onOpenBook!(book);
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => NativeReaderPage(book: book)),
      );
    }
    _reload();
  }

  Future<void> _showStats() async {
    try {
      final stats = await ReadingStatsDao().getSummaryStats();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_text('本地阅读统计', 'Local reading statistics')),
          content: Text(
            _text(
              '今日 ${(stats['today'] ?? 0) ~/ 60} 分钟\n本周 ${(stats['week'] ?? 0) ~/ 60} 分钟\n累计 ${(stats['total'] ?? 0) ~/ 60} 分钟',
              'Today: ${(stats['today'] ?? 0) ~/ 60} minutes\nThis week: ${(stats['week'] ?? 0) ~/ 60} minutes\nTotal: ${(stats['total'] ?? 0) ~/ 60} minutes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_text('关闭', 'Close')),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(_text('无法读取统计：$error', 'Could not load statistics: $error'));
    }
  }

  Future<void> _remove(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text('从书库移除？', 'Remove from library?')),
        content: Text(book.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_text('移除', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed == true && book.id != null) {
      try {
        await _booksDao.deleteBook(book.id!);
        _reload();
      } catch (error) {
        _message(_text('移除失败：$error', 'Removal failed: $error'));
      }
    }
  }

  /// 长按菜单：编辑信息 / 移除。
  Future<void> _showBookActions(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(_text('书籍信息', 'Book info')),
              subtitle: Text(
                '${book.format.toUpperCase()} · ${_text('进度', 'Progress')} ${(book.progress * 100).round()}%',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(_text('更换封面', 'Change cover')),
              subtitle: Text(
                _text('从文件里选一张图片', 'Pick an image file'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _changeCover(book);
              },
            ),
            if (book.coverImagePath != null)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(_text('恢复默认封面', 'Reset cover')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _resetCover(book);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(_text('编辑书名 / 作者', 'Edit title / author')),
              onTap: () {
                Navigator.pop(sheetContext);
                _editBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(_text('从书库移除', 'Remove from library')),
              onTap: () {
                Navigator.pop(sheetContext);
                _remove(book);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 选一张本地图片作为这本书的封面。
  Future<void> _changeCover(Book book) async {
    if (book.id == null) return;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (picked == null || picked.files.isEmpty) return;
      final pickedFile = picked.files.first;
      var bytes = pickedFile.bytes;
      if (bytes == null && pickedFile.path != null) {
        bytes = await File(pickedFile.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        _message(_text('读取图片失败', 'Could not read the image'));
        return;
      }
      final normalized = await _normalizeCoverImage(bytes);
      if (normalized == null) {
        _message(_text('这个图片无法解析', 'This image cannot be decoded'));
        return;
      }
      final path = await CoverGenerator.saveCover(
        normalized,
        book.filePath,
        fileTag: 'custom',
        fileExtension: 'png',
      );
      await _booksDao.updateBookCoverPath(book.id!, path);
      // 同一路径是覆盖写，必须清掉图片缓存才会显示新图。
      await FileImage(File(path)).evict();
      if (!mounted) return;
      _reload();
      _message(_text('封面已更新', 'Cover updated'));
    } catch (error) {
      _message(_text('更换封面失败：$error', 'Cover update failed: $error'));
    }
  }

  /// 恢复自动生成的封面。
  Future<void> _resetCover(Book book) async {
    if (book.id == null) return;
    try {
      final previous = book.coverImagePath;
      await _booksDao.updateBookCoverPath(book.id!, null);
      if (previous != null && !kIsWeb) {
        final file = File(previous);
        await FileImage(file).evict();
        if (await file.exists()) await file.delete();
      }
      if (!mounted) return;
      _reload();
      _message(_text('已恢复默认封面', 'Cover reset'));
    } catch (error) {
      _message(_text('恢复失败：$error', 'Reset failed: $error'));
    }
  }

  /// 解码并等比缩放到最长边 1400 以内，避免把几十 MB 的原图塞进书库。
  Future<Uint8List?> _normalizeCoverImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      var image = frame.image;
      final longest = image.width > image.height ? image.width : image.height;
      if (longest > 1400) {
        final scale = 1400 / longest;
        final targetWidth = (image.width * scale)
            .round()
            .clamp(1, 1400)
            .toInt();
        final targetHeight = (image.height * scale)
            .round()
            .clamp(1, 1400)
            .toInt();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );
        final picture = recorder.endRecording();
        final resized = await picture.toImage(targetWidth, targetHeight);
        picture.dispose();
        image.dispose();
        image = resized;
      }
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 编辑书名 / 作者。
  Future<void> _editBook(Book book) async {
    if (book.id == null) return;
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_text('编辑书籍信息', 'Edit book info')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: _text('书名', 'Title')),
            ),
            TextField(
              controller: authorController,
              decoration: InputDecoration(labelText: _text('作者', 'Author')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('保存', 'Save')),
          ),
        ],
      ),
    );
    final newTitle = titleController.text.trim();
    final newAuthor = authorController.text.trim();
    if (saved == true && newTitle.isNotEmpty) {
      try {
        // 书架列表读的是摘要列（无缓存正文/目录），直接全量更新会把这些列
        // 覆盖成 NULL；先读全量书籍再改。
        final full = await _booksDao.getBookById(book.id!);
        if (full == null) {
          _message(_text('书籍不存在', 'Book not found'));
          return;
        }
        await _booksDao.updateBook(
          full.copyWith(title: newTitle, author: newAuthor),
        );
        _reload();
      } catch (error) {
        _message(_text('保存失败：$error', 'Save failed: $error'));
      }
    }
    titleController.dispose();
    authorController.dispose();
  }

  // ---- 排序 / 筛选 ----

  List<Book> _applySortAndFilter(List<Book> books) {
    final filtered = books.where((book) {
      switch (_filter) {
        case ShelfFilter.all:
          return true;
        case ShelfFilter.unread:
          return book.progress <= 0;
        case ShelfFilter.reading:
          return book.progress > 0 && book.progress < 0.99;
        case ShelfFilter.finished:
          return book.progress >= 0.99;
      }
    }).toList();

    switch (_sort) {
      case ShelfSort.recentRead:
        filtered.sort((a, b) {
          final at = a.lastReadTime ?? 0;
          final bt = b.lastReadTime ?? 0;
          if (at != bt) return bt.compareTo(at);
          return b.importDate.compareTo(a.importDate);
        });
      case ShelfSort.importDate:
        filtered.sort((a, b) => b.importDate.compareTo(a.importDate));
      case ShelfSort.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case ShelfSort.progress:
        filtered.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return filtered;
  }

  String _sortLabel(ShelfSort sort) {
    switch (sort) {
      case ShelfSort.recentRead:
        return _text('最近阅读', 'Recently read');
      case ShelfSort.importDate:
        return _text('导入时间', 'Import date');
      case ShelfSort.title:
        return _text('书名', 'Title');
      case ShelfSort.progress:
        return _text('进度', 'Progress');
    }
  }

  String _filterLabel(ShelfFilter filter) {
    switch (filter) {
      case ShelfFilter.all:
        return _text('全部', 'All');
      case ShelfFilter.unread:
        return _text('未读', 'Unread');
      case ShelfFilter.reading:
        return _text('在读', 'Reading');
      case ShelfFilter.finished:
        return _text('读完', 'Finished');
    }
  }

  // ---- 封面 ----

  Widget _coverImage(Book book, {double? width, double? height}) {
    final cover = book.coverImagePath;
    if (!kIsWeb && cover != null && File(cover).existsSync()) {
      return Image.file(
        File(cover),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _coverPlaceholder(book, width, height),
      );
    }
    return _coverPlaceholder(book, width, height);
  }

  Widget _coverPlaceholder(Book book, double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          book.title.isEmpty ? '书' : book.title.characters.first,
          style: TextStyle(
            fontSize: (width ?? 44) * 0.4,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 未读角标：进度为 0 且导入超过 1 分钟（避开刚导入还没打开的瞬间）。
  bool _isUnread(Book book) =>
      book.progress <= 0 &&
      book.lastReadTime == null &&
      DateTime.now().difference(book.importDate).inMinutes >= 1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('本地书库', 'Local library')),
        actions: [
          PopupMenuButton<ShelfSort>(
            tooltip: _text('排序方式', 'Sort by'),
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: _saveSort,
            itemBuilder: (context) => ShelfSort.values
                .map(
                  (sort) => PopupMenuItem(
                    value: sort,
                    child: Row(
                      children: [
                        Icon(
                          _sort == sort
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(_sortLabel(sort)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: _layout == ShelfLayout.grid
                ? _text('切换为列表', 'Switch to list')
                : _text('切换为网格', 'Switch to grid'),
            onPressed: () => _saveLayout(
              _layout == ShelfLayout.grid ? ShelfLayout.list : ShelfLayout.grid,
            ),
            icon: Icon(
              _layout == ShelfLayout.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
            ),
          ),
          IconButton(
            tooltip: _text('阅读统计', 'Reading statistics'),
            onPressed: _showStats,
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: _text('切换主题', 'Toggle theme'),
            onPressed: () => context.read<ThemeNotifier>().toggleTheme(
              Theme.of(context).brightness != Brightness.dark,
            ),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_text('导入 TXT / EPUB', 'Import TXT / EPUB')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: _text('搜索书名或作者', 'Search title or author'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ShelfFilter.values.map((filter) {
                final selected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Book>>(
              future: _books,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_text('书库加载失败', 'Could not load library')),
                        TextButton(
                          onPressed: _reload,
                          child: Text(_text('重试', 'Retry')),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final searched = snapshot.data!
                    .where(
                      (book) => '${book.title} ${book.author}'
                          .toLowerCase()
                          .contains(_query),
                    )
                    .toList();
                final books = _applySortAndFilter(searched);
                if (books.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.isNotEmpty || _filter != ShelfFilter.all
                            ? _text('没有符合条件的书', 'No matching books')
                            : _text(
                                '导入自己的 TXT 或 EPUB，开始阅读。',
                                'Import your own TXT or EPUB to start reading.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (_layout == ShelfLayout.grid) {
                  return _buildGrid(books, colorScheme);
                }
                return _buildList(books);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Book> books) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: books.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = (book.progress * 100).round();
        return ListTile(
          leading: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: _coverImage(book, width: 44, height: 60),
              ),
              if (_isUnread(book))
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(book.title, maxLines: 1),
          subtitle: Text(
            '${book.author} · ${_text('进度', 'Progress')} $progress%',
          ),
          onTap: () => _open(book),
          onLongPress: () => _showBookActions(book),
          trailing: const Icon(Icons.more_vert),
        );
      },
    );
  }

  Widget _buildGrid(List<Book> books, ColorScheme colorScheme) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 6 : (width > 600 ? 4 : 3);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = (book.progress * 100).round();
        return InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          onTap: () => _open(book),
          onLongPress: () => _showBookActions(book),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      child: _coverImage(book),
                    ),
                    if (_isUnread(book))
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            _text('未读', 'New'),
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onError,
                            ),
                          ),
                        ),
                      ),
                    if (progress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6),
                          ),
                          child: LinearProgressIndicator(
                            value: book.progress,
                            minHeight: 4,
                            backgroundColor: Colors.black26,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '$progress%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
