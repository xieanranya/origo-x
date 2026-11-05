// 文件说明：自定义书源的数据模型与本地存储。
// 书源是一份 JSON 规则，描述某个站点的搜索 / 目录 / 正文分别怎么解析。
// 字段选择器语法：
//   ".item .title"      取该元素文本
//   ".item a@href"      取该元素 href 属性
//   ".item img@src"     取该元素 src 属性
//   "body@html"         取该元素内部 HTML
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 一个书源规则。
class BookSource {
  const BookSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.charset = 'utf-8',
    this.enabled = true,
    this.searchUrl = '',
    this.searchList = '',
    this.searchName = '',
    this.searchAuthor = '',
    this.searchCover = '',
    this.searchLink = '',
    this.tocList = '',
    this.tocName = '',
    this.tocLink = '',
    this.contentSelector = '',
  });

  final String id;
  final String name;

  /// 站点根地址，用于把相对链接补全。
  final String baseUrl;

  /// utf-8 / gbk
  final String charset;
  final bool enabled;

  /// 搜索地址模板，支持 {key} 与 {page}
  final String searchUrl;

  /// 搜索结果：列表容器 + 各字段选择器
  final String searchList;
  final String searchName;
  final String searchAuthor;
  final String searchCover;
  final String searchLink;

  /// 目录：列表容器 + 章节名 + 章节链接
  final String tocList;
  final String tocName;
  final String tocLink;

  /// 正文容器选择器
  final String contentSelector;

  bool get isValid =>
      baseUrl.isNotEmpty &&
      searchUrl.isNotEmpty &&
      searchList.isNotEmpty &&
      searchName.isNotEmpty &&
      searchLink.isNotEmpty &&
      tocList.isNotEmpty &&
      tocName.isNotEmpty &&
      tocLink.isNotEmpty &&
      contentSelector.isNotEmpty;

  BookSource copyWith({bool? enabled}) {
    return BookSource(
      id: id,
      name: name,
      baseUrl: baseUrl,
      charset: charset,
      enabled: enabled ?? this.enabled,
      searchUrl: searchUrl,
      searchList: searchList,
      searchName: searchName,
      searchAuthor: searchAuthor,
      searchCover: searchCover,
      searchLink: searchLink,
      tocList: tocList,
      tocName: tocName,
      tocLink: tocLink,
      contentSelector: contentSelector,
    );
  }

  /// 解析 Legado 书源。
  static BookSource? _fromLegado(Map<String, dynamic> json) {
    final name = (json['bookSourceName'] ?? '').toString().trim();
    final baseUrl = (json['bookSourceUrl'] ?? '').toString().trim();
    if (name.isEmpty || baseUrl.isEmpty) return null;

    Map<String, dynamic> rule(String key) {
      final value = json[key];
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    }

    String field(Map<String, dynamic> map, String key) =>
        (map[key] ?? '').toString();

    final search = rule('ruleSearch');
    final toc = rule('ruleToc');
    final content = rule('ruleContent');

    return BookSource(
      id: 'legado_${baseUrl.hashCode}',
      name: name,
      baseUrl: baseUrl,
      charset: (json['bookSourceCharset'] ?? 'utf-8').toString(),
      enabled: json['enabled'] != false,
      searchUrl: _legadoUrl(field(json, 'searchUrl')),
      searchList: _legadoSelector(field(search, 'bookList')),
      searchName: _legadoSelector(field(search, 'name')),
      searchAuthor: _legadoSelector(field(search, 'author')),
      searchCover: _legadoSelector(field(search, 'coverUrl')),
      searchLink: _legadoSelector(field(search, 'bookUrl')),
      tocList: _legadoSelector(field(toc, 'chapterList')),
      tocName: _legadoSelector(field(toc, 'chapterName')),
      tocLink: _legadoSelector(field(toc, 'chapterUrl')),
      contentSelector: _legadoSelector(field(content, 'content')),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'charset': charset,
    'enabled': enabled,
    'searchUrl': searchUrl,
    'searchList': searchList,
    'searchName': searchName,
    'searchAuthor': searchAuthor,
    'searchCover': searchCover,
    'searchLink': searchLink,
    'tocList': tocList,
    'tocName': tocName,
    'tocLink': tocLink,
    'contentSelector': contentSelector,
  };

  static BookSource? fromJson(Map<String, dynamic> json) {
    // 兼容 Legado（阅读）书源格式：字段名不同，规则是嵌套对象。
    if (json.containsKey('bookSourceUrl') ||
        json.containsKey('bookSourceName')) {
      return _fromLegado(json);
    }
    String str(String key) => (json[key] ?? '').toString();
    final baseUrl = str('baseUrl').trim();
    final name = str('name').trim();
    if (baseUrl.isEmpty || name.isEmpty) return null;
    return BookSource(
      id: json['id']?.toString().isNotEmpty == true
          ? json['id'].toString()
          : 'src_${baseUrl.hashCode}',
      name: name,
      baseUrl: baseUrl,
      charset: json['charset']?.toString() ?? 'utf-8',
      enabled: json['enabled'] != false,
      searchUrl: str('searchUrl'),
      searchList: str('searchList'),
      searchName: str('searchName'),
      searchAuthor: str('searchAuthor'),
      searchCover: str('searchCover'),
      searchLink: str('searchLink'),
      tocList: str('tocList'),
      tocName: str('tocName'),
      tocLink: str('tocLink'),
      contentSelector: str('contentSelector'),
    );
  }
}

/// Legado 选择器转 CSS：class.x → .x，tag.x → x，id.x → #x。
String _legadoSelector(String raw) {
  final s = raw.trim();
  if (s.startsWith('class.')) return '.${s.substring(6)}';
  if (s.startsWith('tag.')) return s.substring(4);
  if (s.startsWith('id.')) return '#${s.substring(3)}';
  return s;
}

/// Legado 地址占位符 {{key}} {{page}} 转成本项目的 {key} {page}。
String _legadoUrl(String raw) {
  var s = raw.trim();
  // Legado 支持 "url,{...}" 形式的分页选项，这里只取前半段地址
  final comma = s.indexOf(',{');
  if (comma > 0) s = s.substring(0, comma);
  return s
      .replaceAll('{{key}}', '{key}')
      .replaceAll('{{page}}', '{page}')
      .replaceAll('{{', '{')
      .replaceAll('}}', '}');
}

/// 搜索结果条目。
class SourceSearchResult {
  const SourceSearchResult({
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.url,
    this.author = '',
    this.cover = '',
  });

  final String sourceId;
  final String sourceName;
  final String title;
  final String url;
  final String author;
  final String cover;
}

/// 目录条目。
class SourceChapter {
  const SourceChapter({required this.title, required this.url});

  final String title;
  final String url;
}

/// 书源存储（本地 JSON）。
class BookSourceStore {
  const BookSourceStore();

  static const String _key = 'custom_book_sources_v1';

  Future<List<BookSource>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <BookSource>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <BookSource>[];
      final result = <BookSource>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final source = BookSource.fromJson(item);
          if (source != null) result.add(source);
        }
      }
      return result;
    } catch (_) {
      return <BookSource>[];
    }
  }

  Future<void> save(List<BookSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(sources.map((e) => e.toJson()).toList()),
    );
  }

  /// 从 JSON 文本导入（支持单个对象或数组）。
  static List<BookSource> parseImport(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return <BookSource>[];
    final decoded = jsonDecode(raw);
    final result = <BookSource>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final source = BookSource.fromJson(item);
          if (source != null) result.add(source);
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      final single = BookSource.fromJson(decoded);
      if (single != null) result.add(single);
    }
    return result;
  }
}
