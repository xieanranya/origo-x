// 文件说明：书源解析引擎。按书源规则抓取并解析搜索 / 目录 / 正文。
// 解析基于 CSS 选择器（package:html），字段支持 "选择器@属性" 语法。
import 'dart:async';
import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'book_source.dart';

class BookSourceException implements Exception {
  BookSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookSourceEngine {
  BookSourceEngine({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 20);

  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  void dispose() => _client.close();

  /// 抓取并解码为字符串。
  Future<String> _fetch(String url, BookSource source) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw BookSourceException('地址无效：$url');
    }
    final response = await _client
        .get(
          uri,
          headers: const {
            'User-Agent': _userAgent,
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
        )
        .timeout(
          _timeout,
          onTimeout: () {
            throw BookSourceException('请求超时：$url');
          },
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BookSourceException('请求失败 ${response.statusCode}：$url');
    }
    final bytes = response.bodyBytes;
    if (source.charset.toLowerCase() == 'gbk') {
      return gbk.decode(bytes);
    }
    // 未显式声明时，若 UTF-8 解码出现替换字符则回退 GBK。
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    if (utf8Text.contains('\uFFFD')) {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        return utf8Text;
      }
    }
    return utf8Text;
  }

  /// 把相对地址补全为绝对地址。
  String _absolute(String base, String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) return trimmed;
    if (trimmed.startsWith('//')) {
      return '${baseUri.scheme}:$trimmed';
    }
    if (trimmed.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}$trimmed';
    }
    final resolved = baseUri.resolve(trimmed);
    return resolved.toString();
  }

  /// 解析单字段选择器："sel@attr" / "sel@text" / "sel"。
  String _extract(dom.Element root, String rule) {
    if (rule.trim().isEmpty) return '';
    final at = rule.lastIndexOf('@');
    var selector = rule;
    String? attr;
    if (at > 0) {
      selector = rule.substring(0, at);
      attr = rule.substring(at + 1).trim().toLowerCase();
    }
    final element = selector.trim().isEmpty
        ? root
        : root.querySelector(selector.trim());
    if (element == null) return '';
    if (attr == null || attr == 'text') {
      return element.text.trim();
    }
    if (attr == 'html') {
      return element.innerHtml;
    }
    return (element.attributes[attr] ?? '').trim();
  }

  /// 搜索。{key} 与 {page} 会被替换。
  Future<List<SourceSearchResult>> search(
    BookSource source,
    String keyword, {
    int page = 1,
  }) async {
    if (source.searchUrl.isEmpty) {
      throw BookSourceException('该来源未配置搜索规则');
    }
    final encoded = Uri.encodeQueryComponent(keyword);
    final path = source.searchUrl
        .replaceAll('{key}', encoded)
        .replaceAll('{page}', '$page');
    final url = _absolute(source.baseUrl, path);
    final html = await _fetch(url, source);
    final document = html_parser.parse(html);
    final items = document.querySelectorAll(source.searchList);
    final results = <SourceSearchResult>[];
    for (final item in items) {
      final title = _extract(item, source.searchName);
      final link = _extract(item, source.searchLink);
      if (title.isEmpty || link.isEmpty) continue;
      results.add(
        SourceSearchResult(
          sourceId: source.id,
          sourceName: source.name,
          title: title,
          url: _absolute(url, link),
          author: _extract(item, source.searchAuthor),
          cover: _absolute(url, _extract(item, source.searchCover)),
        ),
      );
    }
    return results;
  }

  /// 目录。
  Future<List<SourceChapter>> toc(BookSource source, String bookUrl) async {
    final html = await _fetch(bookUrl, source);
    final document = html_parser.parse(html);
    final items = document.querySelectorAll(source.tocList);
    final chapters = <SourceChapter>[];
    for (final item in items) {
      final title = _extract(item, source.tocName);
      final link = _extract(item, source.tocLink);
      if (title.isEmpty || link.isEmpty) continue;
      chapters.add(SourceChapter(title: title, url: _absolute(bookUrl, link)));
    }
    return chapters;
  }

  /// 正文，返回纯文本段落。
  Future<String> content(BookSource source, String chapterUrl) async {
    final html = await _fetch(chapterUrl, source);
    final document = html_parser.parse(html);
    final container = document.querySelector(source.contentSelector);
    if (container == null) {
      throw BookSourceException('未找到正文容器：${source.contentSelector}');
    }
    // 去掉脚本、样式、广告块
    for (final tag in ['script', 'style', 'ins', 'iframe']) {
      for (final node in container.querySelectorAll(tag)) {
        node.remove();
      }
    }
    final buffer = StringBuffer();
    for (final node in container.querySelectorAll('p, div, br')) {
      final text = node.text.trim();
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(text);
    }
    var result = buffer.toString();
    if (result.trim().isEmpty) {
      result = container.text;
    }
    // 压缩多余空行
    result = result
        .replaceAll(RegExp(r'[\t\u00A0]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (result.isEmpty) {
      throw BookSourceException('正文为空，可能规则需要调整');
    }
    return result;
  }
}
