// 文件说明：书源书籍收藏（「发现」页搜索结果的「加入」按钮落到这里）。
// 内核（lib/services）按需求书不允许改，所以书源书籍单独存一份轻量记录，
// 书架把它们和本地书籍一起展示；点开时按 sourceId 找回落库的书源，进目录页。
//
// 注意：这是纯展示层存储，不改 BookDao / BookSourceStore。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 收藏变化信号：书架监听它，发现页一加就刷新。
final ValueNotifier<int> sourceShelfRevision = ValueNotifier<int>(0);

/// 一本来自网络书源的书的轻量记录。
@immutable
class SourceShelfBook {
  const SourceShelfBook({
    required this.id,
    required this.title,
    required this.author,
    required this.sourceId,
    required this.sourceName,
    required this.url,
    this.cover = '',
    this.addedAt = 0,
  });

  /// 唯一键：sourceId + url。
  final String id;
  final String title;
  final String author;
  final String sourceId;
  final String sourceName;

  /// 书籍详情页地址（搜索结果里的 url）。
  final String url;
  final String cover;
  final int addedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'author': author,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'url': url,
    'cover': cover,
    'addedAt': addedAt,
  };

  static SourceShelfBook? fromJson(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    if (id is! String || title is! String || title.isEmpty) return null;
    return SourceShelfBook(
      id: id,
      title: title,
      author: (map['author'] as String?) ?? '',
      sourceId: (map['sourceId'] as String?) ?? '',
      sourceName: (map['sourceName'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
      cover: (map['cover'] as String?) ?? '',
      addedAt: (map['addedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 书源书籍收藏存储（SharedPreferences，单机本地）。
class SourceShelfStore {
  const SourceShelfStore();

  static const String _key = 'source_shelf_books_v1';

  Future<List<SourceShelfBook>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const <SourceShelfBook>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SourceShelfBook>[];
      final result = <SourceShelfBook>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final book = SourceShelfBook.fromJson(item);
          if (book != null) result.add(book);
        }
      }
      return result;
    } catch (_) {
      return const <SourceShelfBook>[];
    }
  }

  /// 加入书架；已存在则返回 false。
  Future<bool> add(SourceShelfBook book) async {
    final list = List<SourceShelfBook>.from(await load());
    if (list.any((item) => item.id == book.id)) return false;
    list.add(book);
    await _save(list);
    sourceShelfRevision.value++;
    return true;
  }

  Future<void> remove(String id) async {
    final list = List<SourceShelfBook>.from(await load())
      ..removeWhere((item) => item.id == id);
    await _save(list);
    sourceShelfRevision.value++;
  }

  Future<void> _save(List<SourceShelfBook> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((item) => item.toJson()).toList()),
    );
  }
}
