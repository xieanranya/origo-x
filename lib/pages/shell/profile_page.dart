// 文件说明：「我的」页按 Rex（聚合媒体播放器）的画面重做：
//   顶部大标题 + 「阅读全掌握」统计卡区（本周柱状 / 热力格 / 今日·本周·累计）
//   + 分组设置列表（纯白大圆角卡、无描边、极轻阴影）。
// 功能行与原来一致：书源管理 / 导入 / 备份 / 深色开关 / 关于。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_version.dart';
import '../../services/core/theme_notifier.dart';
import '../../services/sources/book_source.dart';
import '../shell/app_palette.dart';
import '../sources/book_source_page.dart';
import 'reading_stats_cards.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onImport});

  /// 由外层容器提供：切到书架并打开文件选择器。
  final Future<void> Function()? onImport;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final BookSourceStore _sourceStore = const BookSourceStore();
  int _sourceCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await _sourceStore.load();
      if (!mounted) return;
      setState(() => _sourceCount = sources.where((e) => e.enabled).length);
    } catch (_) {
      // 取不到就显示 0。
    }
  }

  Future<void> _openSources() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const BookSourcePage()));
    await _load();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
              child: Row(
                children: [
                  // 朱红方章：易读的字号标识。
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.cinnabar.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '易',
                      style: TextStyle(
                        fontFamily: AppFont.serif,
                        fontFamilyFallback: AppFont.fallback,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.dark
                            ? const Color(0xFF151815)
                            : const Color(0xFFF7F4EC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的',
                        style: AppText.pageTitle.copyWith(color: palette.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '易读 · 静心读几页',
                        style: AppText.caption.copyWith(
                          color: palette.text3,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: ReadingStatsCards(),
            ),
            _groupTitle('书库', palette),
            _group(palette, [
              _row(
                palette,
                icon: Icons.menu_book_outlined,
                title: '书源管理',
                value: '已启用 $_sourceCount 个',
                onTap: _openSources,
              ),
              _row(
                palette,
                icon: Icons.file_download_outlined,
                title: '导入本地书籍',
                onTap: () async {
                  final handler = widget.onImport;
                  if (handler == null) {
                    _toast('请到「书架」右上角导入');
                    return;
                  }
                  await handler();
                },
              ),
              _row(
                palette,
                icon: Icons.cloud_upload_outlined,
                title: '备份与恢复',
                onTap: () => _toast('备份与恢复还在做，先把书放在本地最稳'),
              ),
            ]),
            _groupTitle('阅读', palette),
            _group(palette, [
              _row(
                palette,
                icon: Icons.format_line_spacing,
                title: '阅读设置',
                value: '字号 · 行距 · 翻页',
                onTap: () => _toast('阅读设置：在阅读页点屏幕中间，底部「排版」里调'),
              ),
              _row(
                palette,
                icon: Icons.volume_up_outlined,
                title: '朗读',
                onTap: () => _toast('朗读在阅读页的控制栏里开启（当前章节朗读）'),
              ),
              _row(
                palette,
                icon: Icons.dark_mode_outlined,
                title: '深色模式',
                trailing: Switch.adaptive(
                  value: isDark,
                  activeThumbColor: palette.accent,
                  onChanged: (value) =>
                      context.read<ThemeNotifier>().toggleTheme(value),
                ),
                showChevron: false,
              ),
            ]),
            _groupTitle('其他', palette),
            _group(palette, [
              _row(
                palette,
                icon: Icons.info_outline,
                title: '关于',
                value: 'v$kAppVersion',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: '易读',
                  applicationVersion: kAppVersion,
                  applicationLegalese: '本地小说与漫画阅读器\n基于 Origo X（AGPL-3.0）',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _groupTitle(String text, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 9),
      child: Row(
        children: [
          // 细金线：分组标题前的小装饰。
          Container(
            width: 14,
            height: 1,
            color: palette.gold.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppText.groupLabel.copyWith(color: palette.text3),
          ),
        ],
      ),
    );
  }

  Widget _group(AppPalette palette, List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: palette.line));
      }
      rows.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _row(
    AppPalette palette, {
    required IconData icon,
    required String title,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    final children = <Widget>[
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: palette.pineSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 17, color: palette.pine),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.rowTitle.copyWith(color: palette.text),
        ),
      ),
    ];
    final valueText = value;
    if (valueText != null) {
      children.add(
        Text(valueText, style: AppText.rowSub.copyWith(color: palette.text3)),
      );
    }
    final tail = trailing;
    if (tail != null) children.add(tail);
    if (showChevron) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.chevron_right, size: 16, color: palette.text3),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: children),
        ),
      ),
    );
  }
}
