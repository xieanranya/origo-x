// 文件说明：新版书架页（封面网格）。替代原「工具感」列表式书架，漫画也并入这里。
// 数据全部复用现有 BookDao / 书源收藏，不改内核：
//   - 本地书籍：BookDao().getAllBooks()、getRecentlyReadBooks(limit: 1)
//   - 书源书籍：SourceShelfStore（本层轻量存储）
// 排序方式沿用 ShelfSort 枚举，偏好键沿用 shelf_sort_mode。
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/book.dart';
import '../../services/books/book_dao.dart';
import '../../services/books/book_import_models.dart';
import '../../services/books/book_import_service.dart';
import '../../services/books/comic_archive_service.dart';
import '../../services/core/theme_notifier.dart';
import '../../services/reading/reading_stats_dao.dart';
import '../../services/sources/book_source.dart';
import '../discover/source_shelf_store.dart';
import '../local_library_page.dart' show ShelfSort;
import '../reader/comic/comic_reader_page.dart';
import '../reader/comic/pdf_reader_page.dart';
import '../reader/native/native_reader_page.dart';
import '../shell/app_palette.dart';
import '../sources/book_source_page.dart';
import 'widgets/book_cover_card.dart';
import 'widgets/continue_reading_card.dart';

class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key});

  @override
  State<ShelfPage> createState() => ShelfPageState();
}

class ShelfPageState extends State<ShelfPage> {
  final BookDao _dao = BookDao();
  final SourceShelfStore _sourceStore = const SourceShelfStore();

  List<Book> _books = const <Book>[];
  List<SourceShelfBook> _sourceBooks = const <SourceShelfBook>[];
  Book? _recent;
  bool _loading = true;
  bool _importing = false;
  ShelfSort _sort = ShelfSort.recentRead;

  static const String _sortKey = 'shelf_sort_mode';

  @override
  void initState() {
    super.initState();
    sourceShelfRevision.addListener(_reloadSources);
    _load();
  }

  @override
  void dispose() {
    sourceShelfRevision.removeListener(_reloadSources);
    super.dispose();
  }

  Future<void> _load() async {
    final sort = await _loadSort();
    List<Book> books = const <Book>[];
    Book? recent;
    try {
      books = await _dao.getAllBooks();
    } catch (error) {
      debugPrint('读取书架失败：$error');
    }
    try {
      final recentBooks = await _dao.getRecentlyReadBooks(limit: 1);
      if (recentBooks.isNotEmpty) recent = recentBooks.first;
    } catch (_) {
      // 没有最近阅读不影响书架。
    }
    final sources = await _sourceStore.load();
    if (!mounted) return;
    setState(() {
      _sort = sort;
      _books = _sorted(books, sort);
      _recent = recent;
      _sourceBooks = sources;
      _loading = false;
    });
  }

  Future<void> _reloadSources() async {
    final sources = await _sourceStore.load();
    if (!mounted) return;
    setState(() => _sourceBooks = sources);
  }

  Future<ShelfSort> _loadSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_sortKey);
      return ShelfSort.values.firstWhere(
        (value) => value.name == name,
        orElse: () => ShelfSort.recentRead,
      );
    } catch (_) {
      return ShelfSort.recentRead;
    }
  }

  Future<void> _saveSort(ShelfSort sort) async {
    setState(() {
      _sort = sort;
      _books = _sorted(_books, sort);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sortKey, sort.name);
    } catch (_) {
      // 存不下也不影响本次排序。
    }
  }

  List<Book> _sorted(List<Book> books, ShelfSort sort) {
    final list = List<Book>.from(books);
    switch (sort) {
      case ShelfSort.recentRead:
        list.sort(
          (a, b) => (b.lastReadTime ?? 0).compareTo(a.lastReadTime ?? 0),
        );
      case ShelfSort.importDate:
        list.sort((a, b) => b.importDate.compareTo(a.importDate));
      case ShelfSort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case ShelfSort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return list;
  }

  // ---------------------------------------------------------------- 打开

  Future<void> _open(Book book) async {
    if (ComicArchiveService.isComicArchive(book.format)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ComicReaderPage(book: book)),
      );
      await _load();
      return;
    }
    if (book.format.toLowerCase() == 'pdf') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PdfReaderPage(book: book)),
      );
      await _load();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => NativeReaderPage(book: book)),
    );
    await _load();
  }

  /// 打开一本收藏的书源书籍：找到对应书源后进目录页。
  Future<void> _openSourceBook(SourceShelfBook book) async {
    final sources = await const BookSourceStore().load();
    BookSource? source;
    for (final item in sources) {
      if (item.id == book.sourceId) {
        source = item;
        break;
      }
    }
    if (!mounted) return;
    if (source == null) {
      _message('这本用的书源已被删除，去「发现 → 书源管理」重新导入');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SourceTocPage(
          source: source!,
          result: SourceSearchResult(
            sourceId: book.sourceId,
            sourceName: book.sourceName,
            title: book.title,
            url: book.url,
            author: book.author,
            cover: book.cover,
          ),
        ),
      ),
    );
    await _load();
  }

  // ---------------------------------------------------------------- 导入

  /// 供「我的」页调用：切到书架后直接开文件选择器。
  Future<void> startImport() => _import();

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
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
        if (ComicArchiveService.isComicArchive(extension)) {
          try {
            final book = await ComicArchiveService.importComic(File(localPath));
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
        skipped == 0 ? '已处理 $imported 本书' : '已导入 $imported 本，$skipped 个文件失败',
      );
      await _load();
    } catch (error) {
      _message('导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

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
    await _dao.insertBook(book);
  }

  // ---------------------------------------------------------------- 菜单

  Future<void> _remove(Book book) async {
    final id = book.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('从书架移除？'),
        content: Text(book.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dao.deleteBook(id);
      await _load();
    } catch (error) {
      _message('移除失败：$error');
    }
  }

  Future<void> _showBookActions(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${book.format.toUpperCase()} · 进度 ${(book.progress * 100).round()}%',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('开始阅读'),
              onTap: () {
                Navigator.pop(sheetContext);
                _open(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('从书架移除'),
              onTap: () {
                Navigator.pop(sheetContext);
                _remove(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSourceBookActions(SourceShelfBook book) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('来源：${book.sourceName}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('从书架移除'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sourceStore.remove(book.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStats() async {
    try {
      final stats = await ReadingStatsDao().getSummaryStats();
      if (!mounted) return;
      final today = (stats['today'] ?? 0) ~/ 60;
      final week = (stats['week'] ?? 0) ~/ 60;
      final total = (stats['total'] ?? 0) ~/ 60;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('阅读统计'),
          content: Text('今日 $today 分钟\n本周 $week 分钟\n累计 $total 分钟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message('无法读取统计：$error');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHead(palette)),
                    if (_continueBook != null)
                      SliverToBoxAdapter(
                        child: ContinueReadingCard(
                          title: _continueBook!.title,
                          subtitle:
                              '已读 ${(_continueBook!.progress * 100).round()}% · 上次读到这里',
                          progress: _continueBook!.progress,
                          coverPath: _continueBook!.coverImagePath,
                          onTap: () => _open(_continueBook!),
                        ),
                      ),
                    SliverToBoxAdapter(child: _buildSectionLabel(palette)),
                    if (_books.isEmpty && _sourceBooks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmpty(palette),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        sliver: SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildCard(index),
                            childCount: _books.length + _sourceBooks.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 「继续阅读」只在 0 < 进度 < 1 时出现。
  Book? get _continueBook {
    final book = _recent;
    if (book == null) return null;
    final progress = book.progress;
    if (progress <= 0.001 || progress >= 0.999) return null;
    return book;
  }

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 900 ? 6 : (width > 600 ? 4 : 3);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 18,
      childAspectRatio: 0.56,
    );
  }

  Widget _buildHead(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('书架', style: AppText.pageTitle.copyWith(color: palette.text)),
          const Spacer(),
          _headIcon(
            icon: Icons.sort_rounded,
            palette: palette,
            onTap: _pickSort,
          ),
          _headIcon(
            icon: Icons.add_rounded,
            palette: palette,
            onTap: _importing ? null : _import,
          ),
          _headIcon(
            icon: Icons.more_vert_rounded,
            palette: palette,
            onTap: _showMore,
          ),
        ],
      ),
    );
  }

  Widget _headIcon({
    required IconData icon,
    required AppPalette palette,
    VoidCallback? onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      iconSize: 24,
      color: palette.text,
      splashRadius: 22,
      icon: Icon(icon),
    );
  }

  Widget _buildSectionLabel(AppPalette palette) {
    final count = _books.length + _sourceBooks.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          Text(
            '全部书籍 · $count 本',
            style: AppText.groupLabel.copyWith(color: palette.text3),
          ),
          const Spacer(),
          Text(
            _sortLabel(_sort),
            style: AppText.groupLabel.copyWith(color: palette.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int index) {
    if (index < _books.length) {
      final book = _books[index];
      return BookCoverCard(
        title: book.title,
        author: book.author,
        progress: book.progress,
        coverPath: book.coverImagePath,
        showUnreadDot: book.lastReadTime == null && book.progress <= 0,
        onTap: () => _open(book),
        onLongPress: () => _showBookActions(book),
      );
    }
    final source = _sourceBooks[index - _books.length];
    return BookCoverCard(
      title: source.title,
      author: source.author.isEmpty ? source.sourceName : source.author,
      badgeText: '书源',
      onTap: () => _openSourceBook(source),
      onLongPress: () => _showSourceBookActions(source),
    );
  }

  Widget _buildEmpty(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 44,
              color: palette.text3.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              '书架还是空的',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '导入自己的 TXT 或 EPUB，开始阅读',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.9, color: palette.text3),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _importing ? null : _import,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '导入书籍',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 小菜单

  static String _sortLabel(ShelfSort sort) => switch (sort) {
    ShelfSort.recentRead => '最近阅读',
    ShelfSort.importDate => '导入时间',
    ShelfSort.title => '书名',
    ShelfSort.progress => '进度',
  };

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<ShelfSort>(
      context: context,
      builder: (sheetContext) {
        final palette = AppPalette.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '排序方式',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
              ),
              for (final sort in ShelfSort.values)
                ListTile(
                  title: Text(
                    _sortLabel(sort),
                    style: TextStyle(
                      fontSize: 14.5,
                      color: sort == _sort ? palette.accent : palette.text,
                    ),
                  ),
                  trailing: sort == _sort
                      ? Icon(Icons.check, size: 18, color: palette.accent)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, sort),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) await _saveSort(picked);
  }

  Future<void> _showMore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('阅读统计'),
              onTap: () => Navigator.pop(sheetContext, 'stats'),
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('切换深色 / 浅色'),
              onTap: () => Navigator.pop(sheetContext, 'theme'),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('书源管理'),
              onTap: () => Navigator.pop(sheetContext, 'sources'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'stats') {
      await _showStats();
    } else if (action == 'theme') {
      context.read<ThemeNotifier>().toggleTheme(
        Theme.of(context).brightness != Brightness.dark,
      );
    } else if (action == 'sources') {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const BookSourcePage()));
      await _load();
    }
  }
}
