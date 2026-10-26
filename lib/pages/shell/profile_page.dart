// 文件说明：「我的」页，工具感样式（v2）：统计三列 + 分组设置列表。
// 数据尽量取真实值，取不到时静默降级为占位，不影响使用。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/books/book_dao.dart';
import '../../services/core/theme_notifier.dart';
import '../../services/reading/reading_stats_dao.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final BookDao _bookDao = BookDao();
  final ReadingStatsDao _statsDao = ReadingStatsDao();

  int _bookCount = 0;
  int _readingMinutes = 0;
  int _bookmarkCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var books = 0;
    var minutes = 0;
    var bookmarks = 0;
    try {
      books = await _bookDao.getBooksCount();
    } catch (_) {
      // 取不到就用 0。
    }
    try {
      final summary = await _statsDao.getSummaryStats();
      final seconds =
          summary['totalSeconds'] ?? summary['totalReadingSeconds'] ?? 0;
      minutes = (seconds / 60).round();
      bookmarks = summary['bookmarkCount'] ?? summary['totalBookmarks'] ?? 0;
    } catch (_) {
      // 统计不可用时保持 0。
    }
    if (!mounted) return;
    setState(() {
      _bookCount = books;
      _readingMinutes = minutes;
      _bookmarkCount = bookmarks;
      _loading = false;
    });
  }

  String get _readingText {
    if (_readingMinutes <= 0) return '0m';
    if (_readingMinutes < 60) return '${_readingMinutes}m';
    final hours = _readingMinutes / 60;
    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F8);
    final subColor = isDark ? const Color(0xFF9A9A9A) : const Color(0xFF7A7A7E);
    final faintColor = isDark ? const Color(0xFF6A6A6A) : const Color(0xFFADADB2);

    Widget statCard(String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: subColor)),
            ],
          ),
        ),
      );
    }

    Widget groupTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: faintColor,
          letterSpacing: 1.2,
        ),
      ),
    );

    Widget row({
      required IconData icon,
      required String title,
      String? value,
      VoidCallback? onTap,
      bool showArrow = true,
    }) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14)),
              ),
              if (value != null)
                Text(value, style: TextStyle(fontSize: 12.5, color: faintColor)),
              if (showArrow)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: faintColor,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget card(List<Widget> children) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              statCard(_loading ? '—' : '$_bookCount', '藏书'),
              const SizedBox(width: 9),
              statCard(_loading ? '—' : _readingText, '本周'),
              const SizedBox(width: 9),
              statCard(_loading ? '—' : '$_bookmarkCount', '书签'),
            ],
          ),
          groupTitle('内容'),
          card([
            row(
              icon: Icons.file_download_outlined,
              title: '导入本地文件',
              value: 'txt · epub',
              onTap: () => _toast('请到「书架」页右下角导入'),
            ),
            row(
              icon: Icons.list_alt,
              title: '书源管理',
              value: '0 个',
              onTap: () => _toast('当前为本地阅读版，暂无网络书源'),
            ),
            row(
              icon: Icons.palette_outlined,
              title: '阅读主题',
              value: '跟随系统',
              onTap: () => _toast('阅读主题在阅读页的设置面板内调整'),
            ),
          ]),
          groupTitle('阅读'),
          card([
            row(
              icon: Icons.bookmark_border,
              title: '批注与书签',
              value: '$_bookmarkCount',
              onTap: () => _toast('在阅读页内添加批注与书签'),
            ),
            row(
              icon: Icons.insights_outlined,
              title: '阅读统计',
              value: _readingText,
              onTap: () => _toast('统计数据来自本地阅读记录'),
            ),
            row(
              icon: Icons.brightness_6_outlined,
              title: '深色模式',
              value: theme.brightness == Brightness.dark ? '已开启' : '跟随系统',
              onTap: () => context.read<ThemeNotifier>().toggleTheme(
                theme.brightness != Brightness.dark,
              ),
            ),
          ]),
          groupTitle('其他'),
          card([
            row(
              icon: Icons.info_outline,
              title: '关于易读',
              value: '2.7.43',
              onTap: () => _about(),
            ),
          ]),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: '易读',
      applicationVersion: '2.7.43',
      applicationLegalese: '本地小说与漫画阅读器\n基于 Origo X（AGPL-3.0）',
    );
  }
}
