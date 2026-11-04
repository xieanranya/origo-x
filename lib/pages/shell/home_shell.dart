// 文件说明：App 外层容器，底部三个页签（书架 / 发现 / 我的）。
// 墨韵改版：底栏从贴边平面条改为「悬浮宣纸胶囊」——半透明纸底 + 细描边 +
// 柔和投影，选中项用松绿；外层留出安全区，内容不被遮挡。
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
    final palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: IndexedStack(
        index: _index,
        children: [
          ShelfPage(key: _shelfKey),
          const DiscoverPage(),
          ProfilePage(onImport: _importFromProfile),
        ],
      ),
      bottomNavigationBar: _FloatingTabBar(
        palette: palette,
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

/// 悬浮胶囊底栏：纸底 + 细边 + 投影，图标 21 / 文字 10.5，选中松绿。
class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + bottomInset),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: palette.float,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: palette.hairline),
          boxShadow: palette.floatShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _TabItem(
                  palette: palette,
                  icon: i == index ? _items[i].$2 : _items[i].$1,
                  label: _items[i].$3,
                  active: i == index,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.palette,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.pine : palette.text3;
    return InkWell(
      onTap: onTap,
      splashColor: palette.pineSoft,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFont.serif,
              fontFamilyFallback: AppFont.fallback,
              fontSize: 10.5,
              height: 1.1,
              letterSpacing: 2,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
