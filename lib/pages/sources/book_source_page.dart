// 文件说明：书源管理页 + 搜索页 + 网络书阅读页。
// 使用流程：导入书源 JSON → 搜索 → 选书 → 看目录 → 读正文（支持上下章）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sources/book_source.dart';
import '../../services/sources/book_source_engine.dart';

/// 书源管理页：导入、启用、删除。
class BookSourcePage extends StatefulWidget {
  const BookSourcePage({super.key});

  @override
  State<BookSourcePage> createState() => _BookSourcePageState();
}

class _BookSourcePageState extends State<BookSourcePage> {
  final BookSourceStore _store = const BookSourceStore();
  List<BookSource> _sources = const <BookSource>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sources = await _store.load();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入书源'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '粘贴书源 JSON（单个对象或数组）。规则字段：\n'
                'searchUrl 支持 {key} {page}；\n'
                '选择器支持 "选择器@属性"，如 a@href、img@src。',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: TextField(
                  controller: controller,
                  maxLines: 8,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '{"name":"示例源","baseUrl":"https://..."}',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) controller.text = data!.text!;
            },
            child: const Text('粘贴'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final imported = BookSourceStore.parseImport(text);
      if (imported.isEmpty) {
        _toast('未解析到有效书源');
        return;
      }
      final merged = <String, BookSource>{
        for (final source in _sources) source.id: source,
        for (final source in imported) source.id: source,
      };
      await _store.save(merged.values.toList());
      await _load();
      _toast('已导入 ${imported.length} 个书源');
    } catch (error) {
      _toast('导入失败：$error');
    }
  }

  Future<void> _remove(BookSource source) async {
    final next = _sources.where((e) => e.id != source.id).toList();
    await _store.save(next);
    await _load();
  }

  Future<void> _toggle(BookSource source, bool enabled) async {
    final next = _sources
        .map((e) => e.id == source.id ? e.copyWith(enabled: enabled) : e)
        .toList();
    await _store.save(next);
    await _load();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F8);
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            tooltip: '导入书源',
            onPressed: _import,
            icon: const Icon(Icons.add_link),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sources.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.travel_explore,
                      size: 44,
                      color: subColor,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '还没有书源',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '书源是一份 JSON 规则，用来告诉程序某个站点的\n搜索、目录、正文怎么解析。\n点右上角导入，或粘贴别人的规则。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.7, color: subColor),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('导入书源'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final source = _sources[index];
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              source.baseUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: subColor),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: source.enabled,
                        onChanged: (value) => _toggle(source, value),
                      ),
                      IconButton(
                        tooltip: '删除',
                        iconSize: 18,
                        color: subColor,
                        onPressed: () => _remove(source),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: _sources.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final enabled = _sources.where((e) => e.enabled).toList();
                if (enabled.isEmpty) {
                  _toast('请先启用至少一个书源');
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SourceSearchPage(sources: enabled),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
    );
  }
}

/// 搜索页：按已启用书源搜索。
class SourceSearchPage extends StatefulWidget {
  const SourceSearchPage({
    super.key,
    required this.sources,
    this.embedded = false,
  });

  final List<BookSource> sources;

  /// 嵌进别的页面时（例如「发现」页）为 true，隐藏自带 AppBar。
  final bool embedded;

  @override
  State<SourceSearchPage> createState() => _SourceSearchPageState();
}

class _SourceSearchPageState extends State<SourceSearchPage> {
  final BookSourceEngine _engine = BookSourceEngine();
  final TextEditingController _controller = TextEditingController();
  List<SourceSearchResult> _results = const <SourceSearchResult>[];
  final Map<String, String> _errors = <String, String>{};
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    _engine.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _searching = true;
      _results = const <SourceSearchResult>[];
      _errors.clear();
    });
    final collected = <SourceSearchResult>[];
    for (final source in widget.sources) {
      try {
        final items = await _engine.search(source, keyword);
        collected.addAll(items);
      } catch (error) {
        _errors[source.name] = error.toString();
      }
      if (!mounted) return;
      setState(() => _results = List<SourceSearchResult>.from(collected));
    }
    if (!mounted) return;
    setState(() => _searching = false);
    if (collected.isEmpty && _errors.isNotEmpty) {
      _toast('搜索失败：${_errors.values.first}');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: '输入书名或作者',
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: Text(_searching ? '搜索中' : '搜索'),
                ),
              ],
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: subColor),
                          const SizedBox(height: 12),
                          Text(
                            _searching ? '正在搜索…' : '输入关键词开始搜索',
                            style: TextStyle(fontSize: 13.5, color: subColor),
                          ),
                          if (_errors.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _errors.entries
                                  .map((e) => '${e.key}：${e.value}')
                                  .join('\n'),
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: subColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.06,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.menu_book,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${item.author.isEmpty ? '未知作者' : item.author} · ${item.sourceName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: subColor),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          final source = widget.sources.firstWhere(
                            (s) => s.id == item.sourceId,
                            orElse: () => widget.sources.first,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SourceTocPage(
                                source: source,
                                result: item,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 目录页 → 阅读页。
class SourceTocPage extends StatefulWidget {
  const SourceTocPage({super.key, required this.source, required this.result});

  final BookSource source;
  final SourceSearchResult result;

  @override
  State<SourceTocPage> createState() => _SourceTocPageState();
}

class _SourceTocPageState extends State<SourceTocPage> {
  final BookSourceEngine _engine = BookSourceEngine();
  List<SourceChapter> _chapters = const <SourceChapter>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadToc();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  Future<void> _loadToc() async {
    try {
      final chapters = await _engine.toc(widget.source, widget.result.url);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loading = false;
        _error = chapters.isEmpty ? '目录为空，检查 tocList 规则' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.result.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: subColor, height: 1.7),
                ),
              ),
            )
          : ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SourceReaderPage(
                          source: widget.source,
                          chapters: _chapters,
                          initialIndex: index,
                          bookTitle: widget.result.title,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// 网络书阅读页：上下章切换，滚动阅读。
class SourceReaderPage extends StatefulWidget {
  const SourceReaderPage({
    super.key,
    required this.source,
    required this.chapters,
    required this.initialIndex,
    required this.bookTitle,
  });

  final BookSource source;
  final List<SourceChapter> chapters;
  final int initialIndex;
  final String bookTitle;

  @override
  State<SourceReaderPage> createState() => _SourceReaderPageState();
}

class _SourceReaderPageState extends State<SourceReaderPage> {
  final BookSourceEngine _engine = BookSourceEngine();
  final ScrollController _scrollController = ScrollController();
  late int _index = widget.initialIndex;
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChapter(_index);
  }

  @override
  void dispose() {
    _engine.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _index = index;
      _loading = true;
      _error = null;
      _content = '';
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    try {
      final text = await _engine.content(widget.source, widget.chapters[index].url);
      if (!mounted) return;
      setState(() {
        _content = text;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapters[_index].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
            Text(
              '${_index + 1} / ${widget.chapters.length} · ${widget.bookTitle}',
              style: TextStyle(fontSize: 11, color: subColor),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: subColor, height: 1.7),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => _loadChapter(_index),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
              children: [
                Text(
                  _content,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.95,
                    color: isDark ? const Color(0xFFCFCABF) : const Color(0xFF23201A),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index > 0
                            ? () => _loadChapter(_index - 1)
                            : null,
                        child: const Text('上一章'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _index < widget.chapters.length - 1
                            ? () => _loadChapter(_index + 1)
                            : null,
                        child: const Text('下一章'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
