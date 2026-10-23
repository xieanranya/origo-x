// 文件说明：Perfect Viewer 风格的漫画阅读菜单面板（全屏半透明覆盖层）。
// 结构对齐参考截图：顶部蓝色图标栏 + 列表式条目。
// 尺寸与配色按截图校准：行高 60、图标 26（彩色）、正文 16.5 加粗纯白、极淡分割线。
// 说明：图标用 Material 语义等价图标实现，不复制原软件的美术资源。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/reader/comic_view_settings.dart';

/// 顶部图标栏的页签。
enum ComicMenuTab {
  menu(Icons.home_rounded, '主菜单'),
  catalog(Icons.menu_book_rounded, '目次'),
  color(Icons.palette_rounded, '调整颜色'),
  settings(Icons.settings_rounded, '设置'),
  history(Icons.history_rounded, '快速前往'),
  bookmark(Icons.bookmark_rounded, '书签');

  const ComicMenuTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// 面板配色与尺寸（对齐截图）。
class _Pv {
  static const Color bar = Color(0xFF4650C8);
  static const Color panel = Color(0xA6000000);
  static const Color divider = Color(0x0FFFFFFF);
  static const Color text = Colors.white;
  static const Color subText = Color(0xCCFFFFFF);
  static const Color icon = Color(0xFFFFFFFF);

  static const double rowHeight = 60;
  static const double iconSize = 26;
  static const double fontSize = 16.5;
  static const FontWeight fontWeight = FontWeight.w500;

  // 图标配色（截图里是彩色图标）。
  static const Color folder = Color(0xFFFFCA28);
  static const Color book = Color(0xFF64B5F6);
  static const Color file = Color(0xFF90CAF9);
  static const Color bookmark = Color(0xFF42A5F5);
  static const Color favorite = Color(0xFFEF5350);
  static const Color star = Color(0xFFFFB300);
  static const Color play = Color(0xFF81C784);
  static const Color download = Color(0xFF4FC3F7);
  static const Color search = Color(0xFFB0BEC5);
  static const Color forward = Color(0xFF90A4AE);
  static const Color toc = Color(0xFF66BB6A);
  static const Color info = Color(0xFF9575CD);
  static const Color share = Color(0xFF4DB6AC);
  static const Color print = Color(0xFFA1887F);
  static const Color delete = Color(0xFFE57373);
  static const Color close = Color(0xFFB0BEC5);
}

/// 全屏菜单面板。
class ComicMenuPanel extends StatefulWidget {
  const ComicMenuPanel({
    super.key,
    required this.settings,
    required this.pageCount,
    required this.spreadCount,
    required this.currentLogicalPage,
    required this.imagePaths,
    required this.onSettingsChanged,
    required this.onJumpToPage,
    required this.onOpenLibrary,
    required this.onImportFile,
    required this.onDeleteBook,
    required this.bookTitle,
    required this.bookPath,
  });

  final ComicViewSettings settings;
  final int pageCount;
  final int spreadCount;
  final int currentLogicalPage;
  final List<String> imagePaths;
  final ValueChanged<ComicViewSettings> onSettingsChanged;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onOpenLibrary;
  final VoidCallback onImportFile;
  final VoidCallback onDeleteBook;
  final String bookTitle;
  final String bookPath;

  @override
  State<ComicMenuPanel> createState() => _ComicMenuPanelState();
}

class _ComicMenuPanelState extends State<ComicMenuPanel> {
  ComicMenuTab _tab = ComicMenuTab.menu;
  final PageController _tabController = PageController();
  late ComicViewSettings _settings = widget.settings;
  bool _colorMasterOn = true;
  List<int> _bookmarks = const <int>[];
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 切换页签（支持点按与左右滑动两种方式）。
  void _switchTab(ComicMenuTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (_tabController.hasClients) {
      _tabController.animateToPage(
        tab.index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_bookmarkKey) ?? const <String>[];
      final list = raw
          .map(int.tryParse)
          .whereType<int>()
          .toList(growable: false)
        ..sort();
      final favorite = prefs.getBool(_favoriteKey) ?? false;
      if (!mounted) return;
      setState(() {
        _bookmarks = list;
        _favorite = favorite;
      });
    } catch (_) {
      // 读取失败不影响使用。
    }
  }

  String get _bookmarkKey => 'comic_bookmarks_${widget.bookPath.hashCode}';
  String get _favoriteKey => 'comic_favorite_${widget.bookPath.hashCode}';

  void _update(ComicViewSettings next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 与原版一致：面板只占屏幕约 88%，右侧与下方露出画面，点面板外即可返回。
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: media.size.width * 0.88,
            height: media.size.height * 0.88,
            child: Container(
              color: _Pv.panel,
              child: Column(
                children: [
                  _buildIconBar(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- 顶部图标栏

  Widget _buildIconBar() {
    return Container(
      height: 56,
      color: _Pv.bar,
      child: Row(
        children: [
          for (final tab in ComicMenuTab.values)
            Expanded(
              child: InkWell(
                onTap: () => _switchTab(tab),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == tab ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Icon(
                    tab.icon,
                    size: 26,
                    color: _tab == tab ? Colors.white : const Color(0xFFD7DBFF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 内容

  Widget _buildBody() {
    // PageView 让左右滑动就能切换页签，和原版一致。
    return PageView(
      controller: _tabController,
      onPageChanged: (index) {
        if (index >= 0 && index < ComicMenuTab.values.length) {
          setState(() => _tab = ComicMenuTab.values[index]);
        }
      },
      children: [
        _buildMainMenu(),
        _buildCatalog(),
        _buildColorTab(),
        _buildSettingsTab(),
        _buildHistoryTab(),
        _buildBookmarkTab(),
      ],
    );
  }

  Widget _buildMainMenu() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvItem(
          icon: Icons.folder_rounded,
          iconColor: _Pv.folder,
          title: '文件浏览器',
          onTap: widget.onOpenLibrary,
        ),
        _PvItem(
          icon: Icons.collections_bookmark_rounded,
          iconColor: _Pv.book,
          title: '我的书柜',
          onTap: widget.onOpenLibrary,
        ),
        _PvItem(
          icon: Icons.insert_drive_file_rounded,
          iconColor: _Pv.file,
          title: '开启文件',
          onTap: widget.onImportFile,
        ),
        _PvItem(
          icon: Icons.bookmark_add_rounded,
          iconColor: _Pv.bookmark,
          title: '插入书签',
          onTap: _addBookmark,
        ),
        _PvItem(
          icon: Icons.folder_special_rounded,
          iconColor: _Pv.star,
          title: '管理我的最爱',
          onTap: _manageFavorites,
        ),
        _PvItem(
          icon: Icons.favorite_rounded,
          iconColor: _Pv.favorite,
          title: '加入我的最爱',
          trailingText: _favorite ? '已加入' : null,
          onTap: _addFavorite,
        ),
        _PvItem(
          icon: Icons.play_circle_outline_rounded,
          iconColor: _Pv.play,
          title: '开始幻灯片播放',
          onTap: () {
            _update(_settings.copyWith(autoTurn: true));
            Navigator.of(context).maybePop();
            _toast('已开始自动翻页，每 ${_settings.autoTurnSeconds} 秒一页');
          },
        ),
        _PvItem(
          icon: Icons.download_rounded,
          iconColor: _Pv.download,
          title: '下载管理',
          onTap: () => _toast('本机漫画为本地文件，没有下载任务'),
        ),
        _PvItem(
          icon: Icons.search_rounded,
          iconColor: _Pv.search,
          title: '对话框放大镜',
          onTap: _magnifier,
        ),
        _PvItem(
          icon: Icons.forward_rounded,
          iconColor: _Pv.forward,
          title: '快速前往',
          onTap: _quickJumpDialog,
        ),
        _PvItem(
          icon: Icons.toc_rounded,
          iconColor: _Pv.toc,
          title: '目次',
          onTap: () => _switchTab(ComicMenuTab.catalog),
        ),
        _PvItem(
          icon: Icons.info_outline_rounded,
          iconColor: _Pv.info,
          title: 'EXIF',
          onTap: _showExif,
        ),
        _PvItem(
          icon: Icons.share_rounded,
          iconColor: _Pv.share,
          title: '分享',
          onTap: _shareInfo,
        ),
        _PvItem(
          icon: Icons.print_rounded,
          iconColor: _Pv.print,
          title: '打印',
          onTap: _printInfo,
        ),
        _PvItem(
          icon: Icons.delete_outline_rounded,
          iconColor: _Pv.delete,
          title: '删除书本',
          onTap: widget.onDeleteBook,
        ),
        _PvItem(
          icon: Icons.exit_to_app_rounded,
          iconColor: _Pv.close,
          title: '关闭',
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildCatalog() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: widget.pageCount,
      itemBuilder: (context, index) => _PvItem(
        icon: Icons.image_outlined,
        iconColor: index == widget.currentLogicalPage
            ? _Pv.book
            : const Color(0x66FFFFFF),
        title: '第 ${index + 1} 页',
        trailingText: index == widget.currentLogicalPage ? '当前' : null,
        onTap: () {
          widget.onJumpToPage(index);
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvInfoRow(
          label: '当前进度',
          value: '第 ${widget.currentLogicalPage + 1} / ${widget.pageCount} 页',
        ),
        _PvItem(
          icon: Icons.first_page_rounded,
          iconColor: _Pv.forward,
          title: '跳到第一页',
          onTap: () => _jump(0),
        ),
        _PvItem(
          icon: Icons.last_page_rounded,
          iconColor: _Pv.forward,
          title: '跳到最后一页',
          onTap: () => _jump(widget.pageCount - 1),
        ),
        _PvItem(
          icon: Icons.fast_forward_rounded,
          iconColor: _Pv.forward,
          title: '前进 10 页',
          onTap: () => _jump(widget.currentLogicalPage + 10),
        ),
        _PvItem(
          icon: Icons.fast_rewind_rounded,
          iconColor: _Pv.forward,
          title: '后退 10 页',
          onTap: () => _jump(widget.currentLogicalPage - 10),
        ),
        _PvItem(
          icon: Icons.pin_rounded,
          iconColor: _Pv.bookmark,
          title: '输入页码跳转',
          onTap: _quickJumpDialog,
        ),
      ],
    );
  }

  Widget _buildBookmarkTab() {
    if (_bookmarks.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        children: const [_PvInfoRow(label: '目前无书签数据', value: '')],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final page = _bookmarks[index];
        return _PvItem(
          icon: Icons.bookmark_rounded,
          iconColor: _Pv.bookmark,
          title: '书签 ${index + 1} · 第 ${page + 1} 页',
          trailingText: '长按删除',
          onTap: () => _jump(page),
          onLongPress: () => _removeBookmark(page),
        );
      },
    );
  }

  // ---------------------------------------------------------- 调整颜色

  Widget _buildColorTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvSwitchItem(
          icon: Icons.settings_rounded,
          iconColor: _Pv.icon,
          title: '调整颜色',
          value: _colorMasterOn,
          onChanged: (value) {
            setState(() => _colorMasterOn = value);
            if (!value) {
              _update(
                _settings.copyWith(
                  brightness: 0,
                  contrast: 1,
                  saturation: 1,
                  hue: 0,
                  gamma: 1,
                  invert: false,
                  grayscale: false,
                  sepia: false,
                  autoLevels: false,
                  sharpen: 0,
                  blur: 0,
                  redBalance: 1,
                  greenBalance: 1,
                  blueBalance: 1,
                ),
              );
            }
          },
        ),
        _PvSliderItem(
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFFE45B5B),
          title: '色彩平衡',
          enabled: _colorMasterOn,
          value: _settings.redBalance,
          min: 0.6,
          max: 1.6,
          divisions: 20,
          valueLabel: '${(_settings.redBalance * 100).round()}%',
          onChanged: (value) => _update(_settings.copyWith(redBalance: value)),
        ),
        _PvSliderItem(
          icon: Icons.tonality_rounded,
          iconColor: const Color(0xFF7C87E8),
          title: '色相 / 彩度',
          enabled: _colorMasterOn,
          value: _settings.saturation,
          min: 0,
          max: 2,
          divisions: 40,
          valueLabel: '${(_settings.saturation * 100).round()}%',
          onChanged: (value) => _update(_settings.copyWith(saturation: value)),
        ),
        _PvSwitchItem(
          icon: Icons.invert_colors_rounded,
          iconColor: const Color(0xFF9C7BE8),
          title: '反相',
          enabled: _colorMasterOn,
          value: _settings.invert,
          onChanged: (value) => _update(_settings.copyWith(invert: value)),
        ),
        _PvSwitchItem(
          icon: Icons.gradient_rounded,
          iconColor: const Color(0xFF90A4AE),
          title: '灰阶',
          enabled: _colorMasterOn,
          value: _settings.grayscale,
          onChanged: (value) => _update(_settings.copyWith(grayscale: value)),
        ),
        _PvSwitchItem(
          icon: Icons.filter_vintage_rounded,
          iconColor: const Color(0xFFC8A165),
          title: '复古色调',
          enabled: _colorMasterOn,
          value: _settings.sepia,
          onChanged: (value) => _update(_settings.copyWith(sepia: value)),
        ),
        _PvSliderItem(
          icon: Icons.details_rounded,
          iconColor: const Color(0xFF4FC3F7),
          title: '图像锐化',
          enabled: _colorMasterOn,
          value: _settings.sharpen,
          min: 0,
          max: 1,
          divisions: 10,
          valueLabel: '${(_settings.sharpen * 100).round()}%',
          onChanged: (value) => _update(_settings.copyWith(sharpen: value)),
        ),
        _PvSliderItem(
          icon: Icons.blur_on_rounded,
          iconColor: const Color(0xFF81C784),
          title: '高斯模糊',
          enabled: _colorMasterOn,
          value: _settings.blur,
          min: 0,
          max: 12,
          divisions: 12,
          valueLabel: _settings.blur.toStringAsFixed(1),
          onChanged: (value) => _update(_settings.copyWith(blur: value)),
        ),
        _PvSliderItem(
          icon: Icons.crop_rounded,
          iconColor: const Color(0xFFFFB74D),
          title: '手工裁切',
          enabled: _colorMasterOn,
          value: _settings.manualCrop,
          min: 0,
          max: 0.3,
          divisions: 30,
          valueLabel: '${(_settings.manualCrop * 100).round()}%',
          onChanged: (value) => _update(_settings.copyWith(manualCrop: value)),
        ),
        _PvSwitchItem(
          icon: Icons.border_clear_rounded,
          iconColor: const Color(0xFFE45B5B),
          title: '自动侦测白边',
          value: _settings.cropBorders,
          useSliderStyle: true,
          onChanged: (value) => _update(_settings.copyWith(cropBorders: value)),
        ),
        _PvSwitchItem(
          icon: Icons.auto_fix_high_rounded,
          iconColor: const Color(0xFFFFD54F),
          title: '自动调整亮度对比',
          enabled: _colorMasterOn,
          value: _settings.autoLevels,
          onChanged: (value) => _update(_settings.copyWith(autoLevels: value)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- 设置

  Widget _buildSettingsTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvPickerItem<ComicPageDirection>(
          icon: Icons.swap_horiz_rounded,
          iconColor: _Pv.book,
          title: '开页方向',
          values: ComicPageDirection.values,
          labelOf: (value) => switch (value) {
            ComicPageDirection.vertical => '由上至下',
            ComicPageDirection.horizontalLeft => '由左至右',
            ComicPageDirection.horizontalRight => '由右至左',
          },
          value: _settings.direction,
          onChanged: (value) => _update(_settings.copyWith(direction: value)),
        ),
        _PvPickerItem<ComicScreenOrientation>(
          icon: Icons.smartphone_rounded,
          iconColor: _Pv.forward,
          title: '屏幕方向',
          values: ComicScreenOrientation.values,
          labelOf: (value) => value.label,
          value: _settings.screenOrientation,
          onChanged: (value) =>
              _update(_settings.copyWith(screenOrientation: value)),
        ),
        _PvPickerItem<ComicFitMode>(
          icon: Icons.fit_screen_rounded,
          iconColor: _Pv.forward,
          title: '缩放方式',
          values: ComicFitMode.values,
          labelOf: (value) => value.label,
          value: _settings.fitMode,
          onChanged: (value) => _update(_settings.copyWith(fitMode: value)),
        ),
        _PvPickerItem<ComicInterfaceTheme>(
          icon: Icons.brightness_6_rounded,
          iconColor: _Pv.star,
          title: '界面主题',
          values: ComicInterfaceTheme.values,
          labelOf: (value) => value.label,
          value: _settings.interfaceTheme,
          onChanged: (value) =>
              _update(_settings.copyWith(interfaceTheme: value)),
        ),
        _PvPickerItem<ComicPageLayout>(
          icon: Icons.auto_stories_rounded,
          iconColor: _Pv.toc,
          title: '阅读模式',
          values: ComicPageLayout.values,
          labelOf: (value) => value.label,
          value: _settings.layout,
          onChanged: (value) => _update(_settings.copyWith(layout: value)),
        ),
        _PvSliderItem(
          icon: Icons.brightness_low_rounded,
          iconColor: _Pv.star,
          title: '背光控制',
          value: _settings.backlight,
          min: 20,
          max: 100,
          divisions: 16,
          valueLabel: _settings.backlight.round().toString(),
          onChanged: (value) => _update(_settings.copyWith(backlight: value)),
        ),
        _PvSliderItem(
          icon: Icons.nightlight_rounded,
          iconColor: const Color(0xFFFFB74D),
          title: '过滤蓝光',
          value: _settings.blueLightFilter,
          min: 0,
          max: 100,
          divisions: 20,
          valueLabel: _settings.blueLightFilter.round().toString(),
          onChanged: (value) =>
              _update(_settings.copyWith(blueLightFilter: value)),
        ),
        _PvSliderItem(
          icon: Icons.border_style_rounded,
          iconColor: _Pv.forward,
          title: '页面边界',
          value: _settings.pageGap,
          min: 0,
          max: 40,
          divisions: 20,
          valueLabel: _settings.pageGap.round().toString(),
          onChanged: (value) => _update(_settings.copyWith(pageGap: value)),
        ),
        _PvSwitchItem(
          icon: Icons.note_add_outlined,
          iconColor: _Pv.book,
          title: '插入空白页作为封里',
          value: _settings.blankFirstPage,
          onChanged: (value) =>
              _update(_settings.copyWith(blankFirstPage: value)),
        ),
        _PvSwitchItem(
          icon: Icons.content_cut_rounded,
          iconColor: _Pv.toc,
          title: '自动分割双页',
          value: _settings.splitDoublePage,
          onChanged: (value) =>
              _update(_settings.copyWith(splitDoublePage: value)),
        ),
        _PvSwitchItem(
          icon: Icons.touch_app_rounded,
          iconColor: _Pv.book,
          title: '点击区域翻页',
          value: _settings.tapToTurn,
          onChanged: (value) => _update(_settings.copyWith(tapToTurn: value)),
        ),
        _PvSwitchItem(
          icon: Icons.linear_scale_rounded,
          iconColor: _Pv.forward,
          title: '显示进度条',
          value: _settings.showProgressBar,
          onChanged: (value) =>
              _update(_settings.copyWith(showProgressBar: value)),
        ),
        _PvSwitchItem(
          icon: Icons.slideshow_rounded,
          iconColor: _Pv.play,
          title: '自动翻页',
          value: _settings.autoTurn,
          onChanged: (value) => _update(_settings.copyWith(autoTurn: value)),
        ),
        if (_settings.autoTurn)
          _PvSliderItem(
            icon: Icons.timer_rounded,
            iconColor: _Pv.play,
            title: '翻页间隔',
            value: _settings.autoTurnSeconds.toDouble(),
            min: 2,
            max: 30,
            divisions: 28,
            valueLabel: '${_settings.autoTurnSeconds} 秒',
            onChanged: (value) => _update(
              _settings.copyWith(autoTurnSeconds: value.round()),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- 动作

  void _jump(int page) {
    widget.onJumpToPage(page.clamp(0, widget.pageCount - 1));
    Navigator.of(context).maybePop();
  }

  Future<void> _addBookmark() async {
    final page = widget.currentLogicalPage;
    final next = {..._bookmarks, page}.toList()..sort();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarkKey, next.map((e) => '$e').toList());
      if (!mounted) return;
      setState(() => _bookmarks = next);
      _toast('已插入书签：第 ${page + 1} 页');
    } catch (_) {
      _toast('插入书签失败');
    }
  }

  Future<void> _removeBookmark(int page) async {
    final next = _bookmarks.where((e) => e != page).toList()..sort();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarkKey, next.map((e) => '$e').toList());
      if (!mounted) return;
      setState(() => _bookmarks = next);
      _toast('已删除该书签');
    } catch (_) {
      _toast('删除书签失败');
    }
  }

  Future<void> _addFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_favoriteKey, !_favorite);
      if (!mounted) return;
      setState(() => _favorite = !_favorite);
      _toast(_favorite ? '已加入我的最爱' : '已移出我的最爱');
    } catch (_) {
      _toast('操作失败');
    }
  }

  void _manageFavorites() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('我的最爱', style: TextStyle(color: Colors.white)),
        content: Text(
          _favorite ? '当前书籍已在我的最爱中。' : '当前书籍不在我的最爱中，可在主菜单点「加入我的最爱」。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _quickJumpDialog() {
    final controller = TextEditingController(
      text: '${widget.currentLogicalPage + 1}',
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('快速前往', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1 ~ ${widget.pageCount}',
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              Navigator.of(context).pop();
              if (page != null) _jump(page - 1);
            },
            child: const Text('前往'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExif() async {
    final index = widget.currentLogicalPage.clamp(
      0,
      widget.imagePaths.isEmpty ? 0 : widget.imagePaths.length - 1,
    );
    if (widget.imagePaths.isEmpty) return;
    final path = widget.imagePaths[index];
    final file = File(path);
    var size = '未知';
    var dimension = '未知';
    try {
      if (await file.exists()) {
        final length = await file.length();
        size = '${(length / 1024).toStringAsFixed(0)} KB';
      }
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 8);
      final frame = await codec.getNextFrame();
      dimension = '${frame.image.width} × ${frame.image.height}';
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      // 读不到就显示未知。
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('EXIF', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _exifLine('文件名', p.basename(path)),
            _exifLine('页序', '第 ${index + 1} 页'),
            _exifLine('尺寸', dimension),
            _exifLine('体积', size),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _exifLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _shareInfo() {
    _toast('分享需要系统分享面板：当前版本可长按书架书籍导出文件');
  }

  void _printInfo() {
    _toast('打印需要 AirPrint 支持：当前版本未接入');
  }

  void _magnifier() {
    _toast('提示：在画面上双指张开即可放大查看细节');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// ---------------------------------------------------------------- 列表项

/// 图标 + 标题 + 右侧文本 的可点条目。
class _PvItem extends StatelessWidget {
  const _PvItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailingText,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: _Pv.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _Pv.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: _Pv.iconSize, color: iconColor),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _Pv.text,
                  fontSize: _Pv.fontSize,
                  fontWeight: _Pv.fontWeight,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(
                  color: _Pv.subText,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 标题 + 右侧值 + 下拉三角，点击弹选择列表。
class _PvPickerItem<T> extends StatelessWidget {
  const _PvPickerItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.values,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<T> values;
  final String Function(T) labelOf;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<T>(
          context: context,
          backgroundColor: const Color(0xFF1B1B1B),
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final option in values)
                  ListTile(
                    title: Text(
                      labelOf(option),
                      style: TextStyle(
                        color: option == value
                            ? const Color(0xFF7C87E8)
                            : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 11, 16, 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _Pv.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: _Pv.iconSize, color: iconColor),
                const SizedBox(width: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: _Pv.text,
                    fontSize: _Pv.fontSize,
                    fontWeight: _Pv.fontWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                Text(
                  labelOf(value),
                  style: const TextStyle(color: _Pv.subText, fontSize: 15),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_drop_down,
                  color: _Pv.subText,
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 图标 + 标题 + 开关。
class _PvSwitchItem extends StatelessWidget {
  const _PvSwitchItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.useSliderStyle = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool useSliderStyle;

  @override
  Widget build(BuildContext context) {
    final activeColor = useSliderStyle
        ? const Color(0xFFE45B5B)
        : const Color(0xFF7C87E8);
    return Container(
      height: _Pv.rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Pv.divider)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: _Pv.iconSize,
            color: enabled ? iconColor : const Color(0x4DFFFFFF),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: enabled ? _Pv.text : const Color(0x80FFFFFF),
                fontSize: _Pv.fontSize,
                fontWeight: _Pv.fontWeight,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

/// 图标 + 标题 + 值 + 滑块。
class _PvSliderItem extends StatelessWidget {
  const _PvSliderItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 14, 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Pv.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: _Pv.iconSize,
                color: enabled ? iconColor : const Color(0x4DFFFFFF),
              ),
              const SizedBox(width: 18),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? _Pv.text : const Color(0x80FFFFFF),
                  fontSize: _Pv.fontSize,
                  fontWeight: _Pv.fontWeight,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: const TextStyle(color: _Pv.subText, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFFE45B5B),
            inactiveColor: const Color(0x33FFFFFF),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

/// 纯信息行。
class _PvInfoRow extends StatelessWidget {
  const _PvInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _Pv.divider)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _Pv.text,
              fontSize: _Pv.fontSize,
              fontWeight: _Pv.fontWeight,
            ),
          ),
          const Spacer(),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(color: _Pv.subText, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
