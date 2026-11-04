// 文件说明：书架页按「开源阅读（Legado iOS）」重做：
//   大标题「我的书架」+ 工具栏（搜索 / 导入 / 更多）+ 分组筛选 chips
//   + 封面列表行（54×74 封面 + 红色未读角标 + 书名 / 作者 / 已读进度）。
// 数据与内核全部复用：BookDao / SourceShelfStore / BookImportService，
// 漫画（cbz/zip/rar/7z）与 PDF 的打开、导入逻辑保持不动。
// 视图可在 列表（Legado iOS 默认）与 封面网格 之间切换，偏好持久化。
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
import 'widgets/cover_art.dart';

enum _ShelfViewMode { list, grid }

enum _ShelfFilter { all, local, source }

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
  _ShelfViewMode _viewMode = _ShelfViewMode.list;
  _ShelfFilter _filter = _ShelfFilter.all;
  String _query = '';

  static const String _sortKey = 'shelf_sort_mode';
  static const String _viewModeKey = 'shelf_view_mode_v2';

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
    final viewMode = await _loadViewMode();
    List<Book> books = const <Book>[];
    try {
      books = await _dao.getAllBooks();
    } catch (error) {
      debugPrint('读取书架失败：$error');
    }
    Book? recent;
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
      _viewMode = viewMode;
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

  Future<_ShelfViewMode> _loadViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_viewModeKey) == 'list'
          ? _ShelfViewMode.list
          : _ShelfViewMode.grid;
    } catch (_) {
      return _ShelfViewMode.grid;
    }
  }

  Future<void> _saveViewMode(_ShelfViewMode mode) async {
    setState(() => _viewMode = mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewModeKey, mode.name);
    } catch (_) {
      // 偏好存不上不影响本次显示。
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

  List<Book> get _visibleBooks {
    var books = _books;
    if (_query.isNotEmpty) {
      books = books
          .where(
            (book) =>
                book.title.toLowerCase().contains(_query) ||
                book.author.toLowerCase().contains(_query),
          )
          .toList(growable: false);
    }
    return books;
  }

  List<SourceShelfBook> get _visibleSourceBooks {
    var sources = _sourceBooks;
    if (_query.isNotEmpty) {
      sources = sources
          .where(
            (book) =>
                book.title.toLowerCase().contains(_query) ||
                book.author.toLowerCase().contains(_query),
          )
          .toList(growable: false);
    }
    return sources;
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
                _load();
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

  Future<void> _showSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = AppPalette.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    controller: TextEditingController(text: _query),
                    onChanged: (value) {
                      _query = value.trim().toLowerCase();
                      if (mounted) setState(() {});
                    },
                    style: TextStyle(fontSize: 15, color: palette.text),
                    decoration: InputDecoration(
                      hintText: '搜书名 / 作者',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: palette.fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() {
      if (_query.isEmpty) _query = '';
    });
  }

  Future<void> _showMore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _viewMode == _ShelfViewMode.list
                    ? Icons.grid_view_outlined
                    : Icons.view_list_outlined,
              ),
              title: Text(
                _viewMode == _ShelfViewMode.list ? '切换为封面网格' : '切换为列表',
              ),
              onTap: () => Navigator.pop(sheetContext, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.sort_rounded),
              title: const Text('排序方式'),
              onTap: () => Navigator.pop(sheetContext, 'sort'),
            ),
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
    switch (action) {
      case 'view':
        await _saveViewMode(
          _viewMode == _ShelfViewMode.list
              ? _ShelfViewMode.grid
              : _ShelfViewMode.list,
        );
      case 'sort':
        await _pickSort();
      case 'stats':
        await _showStats();
      case 'theme':
        context.read<ThemeNotifier>().toggleTheme(
          Theme.of(context).brightness != Brightness.dark,
        );
      case 'sources':
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => const BookSourcePage()));
        await _load();
    }
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
                        child: _buildHeroCard(palette, _continueBook!),
                      ),
                    SliverToBoxAdapter(child: _buildFilterChips(palette)),
                    if (_isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmpty(palette),
                      )
                    else if (_viewMode == _ShelfViewMode.list)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        sliver: SliverToBoxAdapter(
                          child: _buildGroupedCard(palette),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        sliver: SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildGridCard(index),
                            childCount: _visibleCount,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  bool get _isEmpty => _visibleBooks.isEmpty && _visibleSourceBooks.isEmpty;

  int get _visibleCount => _visibleBooks.length + _visibleSourceBooks.length;

  Widget _buildHead(AppPalette palette) {
    final total = _visibleCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 竖排松绿细条，替代图标做标题装饰。
                    Container(
                      width: 3,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.pine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '我的书架',
                      style: AppText.pageTitle.copyWith(color: palette.text),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  total == 0 ? '纸页之间 · 待君添书' : '共 $total 本 · 纸页之间',
                  style: AppText.caption.copyWith(
                    color: palette.text3,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          _headIcon(
            icon: Icons.search_rounded,
            palette: palette,
            tooltip: '搜索书架',
            onTap: _showSearch,
          ),
          _headIcon(
            icon: Icons.add_rounded,
            palette: palette,
            tooltip: '导入本地书籍',
            onTap: _importing ? null : _import,
          ),
          _headIcon(
            icon: Icons.more_horiz_rounded,
            palette: palette,
            tooltip: '更多',
            onTap: _showMore,
          ),
        ],
      ),
    );
  }

  Widget _headIcon({
    required IconData icon,
    required AppPalette palette,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: palette.pineSoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 19, color: palette.pine),
            ),
          ),
        ),
      ),
    );
  }

  /// 0 < 进度 < 1 的最近一本书 → Rex 式「继续阅读」白卡。
  Book? get _continueBook {
    final book = _recent;
    if (book == null) return null;
    final progress = book.progress;
    if (progress <= 0.001 || progress >= 0.999) return null;
    return book;
  }

  Widget _buildHeroCard(AppPalette palette, Book book) {
    final percent = (book.progress * 100).round();
    final meta = book.author.trim().isEmpty
        ? '${book.format.toUpperCase()} · $percent%'
        : '${book.author} · $percent%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: palette.hairline),
          boxShadow: palette.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SpineCover(
              title: book.title,
              path: book.coverImagePath,
              width: 74,
              height: 106,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 106,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: palette.cinnabar,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '上次读到',
                          style: AppText.caption.copyWith(
                            color: palette.text3,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sectionTitle.copyWith(
                        fontSize: 17,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bookAuthor.copyWith(
                        color: palette.text3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: book.progress.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: palette.fill,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.pine,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _open(book),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: palette.pine,
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.pine.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '续读',
                              style: AppText.rowSub.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                color: palette.dark
                                    ? const Color(0xFF151815)
                                    : const Color(0xFFF7F4EC),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppPalette palette) {
    Widget chip(String label, _ShelfFilter value) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? palette.pine : palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: selected ? Colors.transparent : palette.hairline,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.pine.withValues(alpha: 0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppText.rowSub.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 1.5,
                color: selected
                    ? (palette.dark
                          ? const Color(0xFF151815)
                          : const Color(0xFFF7F4EC))
                    : palette.text2,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        children: [
          chip('全部', _ShelfFilter.all),
          chip('本地书籍', _ShelfFilter.local),
          chip('书源书籍', _ShelfFilter.source),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => setState(() => _query = ''),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: palette.cinnabar.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: palette.cinnabar.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '“$_query”',
                        style: AppText.rowSub.copyWith(
                          color: palette.cinnabar,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.close, size: 13, color: palette.cinnabar),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// iOS insetGrouped 风格：整组白卡 + 行分隔线（左侧让出封面宽度）。
  Widget _buildGroupedCard(AppPalette palette) {
    final books = _visibleBooks;
    final sources = _visibleSourceBooks;
    final rows = <Widget>[];

    void addBookRow(Book book) {
      if (rows.isNotEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 82),
            child: Divider(height: 1, thickness: 0.6, color: palette.line),
          ),
        );
      }
      rows.add(
        _LocalBookRow(
          book: book,
          onTap: () => _open(book),
          onLongPress: () => _showBookActions(book),
        ),
      );
    }

    void addSourceRow(SourceShelfBook book) {
      if (rows.isNotEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 82),
            child: Divider(height: 1, thickness: 0.6, color: palette.line),
          ),
        );
      }
      rows.add(
        _SourceBookRow(
          book: book,
          onTap: () => _openSourceBook(book),
          onLongPress: () => _showSourceBookActions(book),
        ),
      );
    }

    switch (_filter) {
      case _ShelfFilter.all:
        for (final book in books) {
          addBookRow(book);
        }
        for (final source in sources) {
          addSourceRow(source);
        }
      case _ShelfFilter.local:
        for (final book in books) {
          addBookRow(book);
        }
      case _ShelfFilter.source:
        for (final source in sources) {
          addSourceRow(source);
        }
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
        boxShadow: palette.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _buildGridCard(int index) {
    if (index < _visibleBooks.length) {
      final book = _visibleBooks[index];
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
    final source = _visibleSourceBooks[index - _visibleBooks.length];
    return BookCoverCard(
      title: source.title,
      author: source.author.isEmpty ? source.sourceName : source.author,
      badgeText: '书源',
      onTap: () => _openSourceBook(source),
      onLongPress: () => _showSourceBookActions(source),
    );
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

  Widget _buildEmpty(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 朱红印章 + 水墨圈，替代通用图标。
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: palette.cinnabar.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.cinnabar.withValues(alpha: 0.28),
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.cinnabar.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '藏',
                  style: TextStyle(
                    fontFamily: AppFont.serif,
                    fontFamilyFallback: AppFont.fallback,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.dark
                        ? const Color(0xFF151815)
                        : const Color(0xFFF7F4EC),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '书架空空如也',
              style: AppText.sectionTitle.copyWith(
                fontSize: 17,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '点击右上角 + 导入本地 TXT / EPUB\n或到「发现」用书源搜索网络小说',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(
                fontSize: 12.5,
                height: 1.9,
                letterSpacing: 1,
                color: palette.text3,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _importing ? null : _import,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: palette.pine,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: palette.pine.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: palette.dark
                          ? const Color(0xFF151815)
                          : const Color(0xFFF7F4EC),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '导入书籍',
                      style: AppText.rowTitle.copyWith(
                        letterSpacing: 2,
                        color: palette.dark
                            ? const Color(0xFF151815)
                            : const Color(0xFFF7F4EC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sortLabel(ShelfSort sort) => switch (sort) {
    ShelfSort.recentRead => '最近阅读',
    ShelfSort.importDate => '导入时间',
    ShelfSort.title => '书名',
    ShelfSort.progress => '进度',
  };
}

// ---------------------------------------------------------------- 列表行

/// 本地书籍行：54×74 封面 + 未读红角标 + 书名 / 作者 / 已读行。
class _LocalBookRow extends StatelessWidget {
  const _LocalBookRow({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final neverRead = book.lastReadTime == null && book.progress <= 0;
    final readLabel = book.totalPages > 1
        ? '已读: 第 ${book.currentPage + 1} / ${book.totalPages} 页'
        : '已读: ${(book.progress * 100).round()}%';
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 74,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CoverArt(
                      title: book.title,
                      path: book.coverImagePath,
                      radius: 6,
                      glyphSize: 22,
                    ),
                  ),
                  if (neverRead)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.cinnabar,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: palette.surface,
                            width: 1.4,
                          ),
                        ),
                        child: const Text(
                          '未读',
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bookName.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  if (book.author.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bookAuthor.copyWith(color: palette.text3),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    readLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: neverRead ? palette.text3 : palette.pine,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.text3),
          ],
        ),
      ),
    );
  }
}

/// 书源书籍行。
class _SourceBookRow extends StatelessWidget {
  const _SourceBookRow({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  final SourceShelfBook book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 74,
              child: CoverArt(title: book.title, radius: 6, glyphSize: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bookName.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book.author.isEmpty ? '佚名' : book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bookAuthor.copyWith(color: palette.text3),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.pineSoft,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '书源 · ${book.sourceName}',
                      style: AppText.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: palette.pine,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.text3),
          ],
        ),
      ),
    );
  }
}

/// 书脊立体封面：左侧压暗 + 底部投影，让平封面看起来有「书」的厚度。
class _SpineCover extends StatelessWidget {
  const _SpineCover({
    required this.title,
    this.path,
    required this.width,
    required this.height,
  });

  final String title;
  final String? path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E26261F),
            blurRadius: 14,
            offset: Offset(4, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverArt(title: title, path: path, radius: 5, glyphSize: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 8,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(width: 2, color: const Color(0x1FFFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
