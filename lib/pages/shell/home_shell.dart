// 文件说明：App 外层容器，底部三个页签（书架 / 漫画 / 我的），
// 用 IndexedStack 保留各页状态，切换不重建。
import 'package:flutter/material.dart';

import '../local_library_page.dart';
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final GlobalKey<LocalLibraryPageState> _shelfKey =
      GlobalKey<LocalLibraryPageState>();

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
          LocalLibraryPage(key: _shelfKey),
          const LocalLibraryPage(comicOnly: true),
          ProfilePage(onImport: _importFromProfile),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '漫画',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
