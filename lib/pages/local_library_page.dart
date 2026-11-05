import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
import 'reader/comic/pdf_reader_page.dart';
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
    this.comicOnly = false,
  });

  final Future<List<Book>> Function()? booksLoader;
  final Future<void> Function(Book)? onOpenBook;
  final Future<void> Function()? onImport;

  /// 只显示漫画类书籍（供底部「漫画」页签使用）。
  final bool comicOnly;

  @override
  State<LocalLibraryPage> createState() => LocalLibraryPageState();
}

class LocalLibraryPageState extends State<LocalLibraryPage> {
  final _booksDao = BookDao();
  late Future<List<Book>> _books;
  bool _importing = false;
  String _query = '';
  ShelfLayout _layout = ShelfLayout.list;
  ShelfSort _sort = ShelfSort.importDate;
  ShelfFilter _filter = ShelfFilter.all;

  // v2：键名变更，使旧的「网格」偏好失效，默认展示新版紧凑列表。
  static const _prefLayoutKey = 'shelf_layout_mode_v2';
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

  /// 供外部（如「我的」页）直接触发导入。
  Future<void> startImport() => _import();

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      if (widget.onImport != null) {
        await widget.onImport!();
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'txt',
            'epub',
            'cbz',
            'zip',
            'cbr',
            'rar',
            'cb7',
            '7z',
            'pdf',
          ],
          allowMultiple: true,
          withData: kIsWeb,
        );
        if (result == null) return;
        final importer = BookImportService();
        var imported = 0;
        var skipped = 0;
        for (final file in result.files) {
          final localPath = file.path;
          if (localPath == null) continue;
          final extension = p
              .extension(localPath)
              .replaceFirst('.', '')
              .toLowerCase();
          // 漫画压缩包：解压图片后按图片流阅读。
          if (ComicArchiveService.isComicArchive(extension)) {
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
          // PDF：直接复制入库，页数等打开阅读页时回填。
          if (extension == 'pdf') {
            try {
              await _importPdf(File(localPath));
              imported++;
            } catch (error) {
              skipped++;
              debugPrint('PDF 导入失败 ${file.name}: $error');
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
                  '已导入 $imported 本，$skipped 个文件失败',
                  'Imported $imported, $skipped file(s) failed',
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
    // 漫画走图片阅读页，PDF 走原生渲染页，都与文本阅读器分开。
    if (ComicArchiveService.isComicArchive(book.format)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ComicReaderPage(book: book)),
      );
      _reload();
      return;
    }
    if (book.format.toLowerCase() == 'pdf') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PdfReaderPage(book: book)),
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

  /// 复制 PDF 到书库并建记录；真实页数在阅读页打开时回填。
  Future<void> _importPdf(File source) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final pdfsDir = Directory(p.join(documentsDir.path, 'pdfs'));
    await pdfsDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final target = p.join(pdfsDir.path, '${stamp}_${p.basename(source.path)}');
    await source.copy(target);
    final book = Book(
      title: p.basenameWithoutExtension(source.path),
      author: '',
      filePath: target,
      format: 'PDF',
      currentPage: 0,
      totalPages: 1,
      readingProgress: 0,
      importDate: DateTime.now(),
    );
    await _booksDao.insertBook(book);
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

  /// 粗略判断一本是否属于漫画/压缩包类。
  bool _looksLikeComic(Book book) {
    final format = book.format.toLowerCase();
    if (format.contains('comic') ||
        format.contains('cbz') ||
        format.contains('cbr') ||
        format.contains('pdf')) {
      return true;
    }
    final ext = p.extension(book.filePath).toLowerCase();
    return const <String>{
      '.cbz',
      '.cbr',
      '.cb7',
      '.pdf',
      '.zip',
      '.rar',
      '.7z',
    }.contains(ext);
  }

  List<Book> _applySortAndFilter(List<Book> books) {
    final source = widget.comicOnly
        ? books.where(_looksLikeComic).toList()
        : books;
    final filtered = source.where((book) {
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
        title: Text(
          widget.comicOnly ? _text('漫画', 'Comics') : _text('书架', 'Bookshelf'),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 36,
                ),
                hintText: _text('搜索书名或作者', 'Search title or author'),
                hintStyle: const TextStyle(fontSize: 13.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.07,
    );
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);
    final faintColor = isDark
        ? const Color(0xFF6A6A6A)
        : const Color(0xFFADADB2);

    Widget statusBadge(String label, Color fg, Color bg) {
      return Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: fg,
            height: 1.3,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = book.progress.clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final isRead = progress >= 0.999;
        final isReading = progress > 0 && !isRead;

        return InkWell(
          onTap: () => _open(book),
          onLongPress: () => _showBookActions(book),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: lineColor)),
            ),
            child: Row(
              children: [
                // 封面
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      child: _coverImage(book, width: 42, height: 58),
                    ),
                    if (_isUnread(book))
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // 标题 + 作者
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (isReading)
                            statusBadge(
                              _text('在读', 'Reading'),
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.12),
                            ),
                          if (isRead)
                            statusBadge(
                              _text('已读完', 'Finished'),
                              faintColor,
                              faintColor.withValues(alpha: 0.14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              book.author.isEmpty
                                  ? _text('未知作者', 'Unknown')
                                  : book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: subColor),
                            ),
                          ),
                          if (book.totalPages > 0) ...[
                            Container(
                              width: 1,
                              height: 9,
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              color: lineColor,
                            ),
                            Text(
                              '${book.currentPage + 1}/${book.totalPages}',
                              style: TextStyle(fontSize: 11.5, color: subColor),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 百分比 + 细进度条
                SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 11,
                          color: faintColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.5,
                          backgroundColor: lineColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: faintColor,
                    tooltip: _text('更多', 'More'),
                    onPressed: () => _showBookActions(book),
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<Book> books, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);
    final lineColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.09,
    );
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 6 : (width > 600 ? 4 : 3);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.60,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = book.progress.clamp(0.0, 1.0);
        final percent = (progress * 100).round();
        final isRead = progress >= 0.999;
        final isReading = progress > 0 && !isRead;

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
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: _coverImage(book),
                    ),
                    // 底部渐隐，让百分比在任何封面上都看得清
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(7, 16, 7, 6),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xA6000000)],
                          ),
                        ),
                        child: Row(
                          children: [
                            if (isReading)
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _text('在读', 'Reading'),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            if (isRead)
                              Container(
                                margin: const EdgeInsets.only(right: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _text('读完', 'Done'),
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isUnread(book))
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.05,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(1.5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: lineColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isRead
                        ? subColor.withValues(alpha: 0.5)
                        : colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
