// 文件说明：App 外层容器，底部三个页签（书架 / 发现 / 我的）。
// 底栏按「开源阅读」的 iOS 版样式重做：细分割线 + 平面图标/文字，
// 不再用 Material NavigationBar 的胶囊指示器。漫画已并入书架。
import 'package:flutter/material.dart';

import '../discover/discover_page.dart';
import '../shelf/shelf_page.dart';
import 'app_palette.dart';
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final GlobalKey<ShelfPageState> _shelfKey = GlobalKey<ShelfPageState>();

  /// 从「我的」页触发导入：先切到书架，再打开文件选择器，
  /// 导入完成后停留在书架，直接看到结果。
  Future<void> _importFromProfile() async {
    if (_index != 0) {
      setState(() => _index = 0);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    await _shelfKey.currentState?.startImport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ShelfPage(key: _shelfKey),
          const DiscoverPage(),
          ProfilePage(onImport: _importFromProfile),
        ],
      ),
      bottomNavigationBar: _LegadoTabBar(
        palette: AppPalette.of(context),
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

/// 平面 tab 栏：细顶边 + 图标 22 / 文字 10，选中用强调色。
class _LegadoTabBar extends StatelessWidget {
  const _LegadoTabBar({
    required this.palette,
    required this.index,
    required this.onChanged,
  });

  final AppPalette palette;
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <(IconData, IconData, String)>[
    (Icons.auto_stories_outlined, Icons.auto_stories, '书架'),
    (Icons.travel_explore_outlined, Icons.travel_explore, '发现'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? _items[i].$2 : _items[i].$1,
                          size: 22,
                          color: i == index ? palette.accent : palette.text3,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == index ? palette.accent : palette.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
