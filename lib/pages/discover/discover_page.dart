// 文件说明：新版「发现」页：顶部标题 + 吸顶搜索框 + 书源筛选 chips + 结果列表。
// 内核不动：书源读取用 BookSourceStore，搜索直接调 BookSourceEngine
// （与 SourceSearchPage 同一套引擎），结果可「加入」到书架（SourceShelfStore）。
import 'package:flutter/material.dart';

import '../../services/sources/book_source.dart';
import '../../services/sources/book_source_engine.dart';
import '../shell/app_palette.dart';
import '../shelf/widgets/cover_art.dart';
import '../sources/book_source_page.dart';
import 'source_shelf_store.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final BookSourceStore _sourceStore = const BookSourceStore();
  final BookSourceEngine _engine = BookSourceEngine();
  final SourceShelfStore _shelfStore = const SourceShelfStore();
  final TextEditingController _keyword = TextEditingController();

  List<BookSource> _enabledSources = const <BookSource>[];
  String? _activeSourceId; // null = 全部书源
  List<SourceSearchResult> _results = const <SourceSearchResult>[];
  bool _loadingSources = true;
  bool _searching = false;
  String _submitted = '';

  /// 每次搜索递增，旧请求的结果直接丢弃（换关键词/换书源时不会串）。
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _keyword.addListener(_onKeywordChanged);
    _loadSources();
  }

  /// 输入框有无内容要切换清除按钮，所以跟着刷新一下。
  void _onKeywordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _keyword.removeListener(_onKeywordChanged);
    _keyword.dispose();
    _engine.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    final all = await _sourceStore.load();
    if (!mounted) return;
    setState(() {
      _enabledSources = all.where((item) => item.enabled).toList();
      _loadingSources = false;
      if (_activeSourceId != null &&
          !_enabledSources.any((item) => item.id == _activeSourceId)) {
        _activeSourceId = null;
      }
    });
  }

  List<BookSource> get _targets {
    final id = _activeSourceId;
    if (id == null) return _enabledSources;
    return _enabledSources.where((item) => item.id == id).toList();
  }

  Future<void> _search() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _submitted = '';
        _results = const <SourceSearchResult>[];
      });
      return;
    }
    if (_enabledSources.isEmpty) return;
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _submitted = keyword;
      _results = const <SourceSearchResult>[];
    });
    final collected = <SourceSearchResult>[];
    for (final source in _targets) {
      try {
        final items = await _engine.search(source, keyword);
        collected.addAll(items);
      } catch (_) {
        // 单个书源失败不影响其它书源。
      }
      if (!mounted || token != _searchToken) return;
      // 结果随书源返回逐条追加。
      setState(() => _results = List<SourceSearchResult>.from(collected));
    }
    if (!mounted || token != _searchToken) return;
    setState(() => _searching = false);
  }

  Future<void> _addToShelf(SourceSearchResult result) async {
    final added = await _shelfStore.add(
      SourceShelfBook(
        id: '${result.sourceId}::${result.url}',
        title: result.title,
        author: result.author,
        sourceId: result.sourceId,
        sourceName: result.sourceName,
        url: result.url,
        cover: result.cover,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    _toast(added ? '已加入书架' : '这本书已经在书架里了');
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openSources() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const BookSourcePage()),
    );
    await _loadSources();
    if (_keyword.text.trim().isNotEmpty) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHead(palette),
            _buildSearchBox(palette),
            _buildChips(palette),
            SizedBox(
              height: 2,
              child: _searching
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: palette.fill,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    )
                  : null,
            ),
            Expanded(child: _buildBody(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildHead(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: palette.pine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现',
                  style: AppText.pageTitle.copyWith(color: palette.text),
                ),
                const SizedBox(height: 7),
                Text(
                  '书源搜书 · 拾遗补缺',
                  style: AppText.caption.copyWith(
                    color: palette.text3,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: '书源管理',
            child: Material(
              color: palette.pineSoft,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _openSources,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: palette.pine,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _keyword,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          style: AppText.rowTitle.copyWith(color: palette.text),
          cursorColor: palette.pine,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: palette.surface,
            hintText: '搜书名 / 作者',
            hintStyle: AppText.rowTitle.copyWith(color: palette.text3),
            prefixIcon: Icon(Icons.search, size: 18, color: palette.pine),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              borderSide: BorderSide(color: palette.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              borderSide: BorderSide(color: palette.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              borderSide: BorderSide(color: palette.pine, width: 1.2),
            ),
            suffixIcon: _keyword.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _keyword.clear();
                      _search();
                    },
                    icon: Icon(Icons.close, size: 16, color: palette.text3),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildChips(AppPalette palette) {
    if (_enabledSources.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip(palette, label: '全部', selected: _activeSourceId == null, id: null),
          for (final source in _enabledSources)
            _chip(
              palette,
              label: source.name,
              selected: _activeSourceId == source.id,
              id: source.id,
            ),
        ],
      ),
    );
  }

  Widget _chip(
    AppPalette palette, {
    required String label,
    required bool selected,
    required String? id,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (_activeSourceId == id) return;
          setState(() => _activeSourceId = id);
          if (_submitted.isNotEmpty) _search();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? palette.pine : palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: selected ? Colors.transparent : palette.hairline,
            ),
          ),
          child: Text(
            label,
            style: AppText.rowSub.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 1.2,
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

  Widget _buildBody(AppPalette palette) {
    if (_loadingSources) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_enabledSources.isEmpty) {
      return _empty(
        palette,
        icon: Icons.cloud_off_outlined,
        title: '还没有启用书源',
        subtitle: '导入书源 JSON 后就能在这里搜书',
        action: GestureDetector(
          onTap: _openSources,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: palette.pine,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: palette.pine.withValues(alpha: 0.26),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              '导入书源',
              style: AppText.rowTitle.copyWith(
                fontSize: 14,
                letterSpacing: 2,
                color: palette.dark
                    ? const Color(0xFF151815)
                    : const Color(0xFFF7F4EC),
              ),
            ),
          ),
        ),
      );
    }
    if (_results.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: _results.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(left: 78),
          child: Divider(height: 1, thickness: 1, color: palette.line),
        ),
        itemBuilder: (context, index) => _buildResult(_results[index], palette),
      );
    }
    if (_searching) return const SizedBox.shrink();
    if (_submitted.isNotEmpty) {
      return _empty(
        palette,
        icon: Icons.search_off_rounded,
        title: '没有找到「$_submitted」',
        subtitle: '换个关键词，或到书源管理里检查书源是否失效',
      );
    }
    return _empty(
      palette,
      icon: Icons.travel_explore_rounded,
      title: '搜书名 / 作者',
      subtitle: '结果来自已启用的 ${_enabledSources.length} 个书源',
    );
  }

  Widget _buildResult(SourceSearchResult item, AppPalette palette) {
    return InkWell(
      onTap: () async {
        final sources = await _sourceStore.load();
        BookSource? source;
        for (final candidate in sources) {
          if (candidate.id == item.sourceId) {
            source = candidate;
            break;
          }
        }
        if (!mounted || source == null) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                SourceTocPage(source: source!, result: item),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 61,
              child: CoverArt(
                title: item.title,
                radius: 8,
                glyphSize: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bookName.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.author.isEmpty ? '未知作者' : item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bookAuthor.copyWith(
                            color: palette.text3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: palette.pineSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.sourceName,
                          style: AppText.caption.copyWith(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: palette.pine,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addToShelf(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: palette.pine.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '加入',
                  style: AppText.rowSub.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: palette.pine,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(
    AppPalette palette, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final children = <Widget>[
      Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: palette.pineSoft,
          shape: BoxShape.circle,
          border: Border.all(color: palette.hairline),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 28, color: palette.pine),
      ),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppText.sectionTitle.copyWith(
          fontSize: 16,
          color: palette.text,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AppText.caption.copyWith(
          fontSize: 12.5,
          height: 1.9,
          color: palette.text3,
        ),
      ),
    ];
    final button = action;
    if (button != null) {
      children.add(const SizedBox(height: 18));
      children.add(button);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
