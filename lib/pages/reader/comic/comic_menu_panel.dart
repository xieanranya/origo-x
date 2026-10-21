// 文件说明：Perfect Viewer 风格的漫画阅读菜单面板（全屏半透明覆盖层）。
// 结构对齐参考截图：顶部蓝色图标栏 + 列表式条目（标题 / 下拉值 / 开关 / 滑块）。
// 说明：图标用 Material 语义等价图标实现，不复制原软件的美术资源。
import 'package:flutter/material.dart';

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

/// 面板配色（对齐截图）。
class _PvColors {
  static const Color bar = Color(0xFF4650C8);
  static const Color panel = Color(0xD9000000);
  static const Color divider = Color(0x26FFFFFF);
  static const Color text = Colors.white;
  static const Color subText = Color(0xB3FFFFFF);
  static const Color icon = Color(0xE6FFFFFF);
}

/// 全屏菜单面板。
class ComicMenuPanel extends StatefulWidget {
  const ComicMenuPanel({
    super.key,
    required this.settings,
    required this.pageCount,
    required this.spreadCount,
    required this.currentLogicalPage,
    required this.onSettingsChanged,
    required this.onJumpToPage,
    required this.onCloseBook,
    required this.bookTitle,
    required this.bookPath,
  });

  final ComicViewSettings settings;
  final int pageCount;
  final int spreadCount;
  final int currentLogicalPage;
  final ValueChanged<ComicViewSettings> onSettingsChanged;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onCloseBook;
  final String bookTitle;
  final String bookPath;

  @override
  State<ComicMenuPanel> createState() => _ComicMenuPanelState();
}

class _ComicMenuPanelState extends State<ComicMenuPanel> {
  ComicMenuTab _tab = ComicMenuTab.menu;
  late ComicViewSettings _settings = widget.settings;
  bool _colorMasterOn = true;

  void _update(ComicViewSettings next) {
    setState(() => _settings = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: _PvColors.panel,
        child: SafeArea(
          child: Column(
            children: [
              _buildIconBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- 顶部图标栏

  Widget _buildIconBar() {
    return Container(
      height: 56,
      color: _PvColors.bar,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final tab in ComicMenuTab.values)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = tab),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == tab
                            ? Colors.white
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Icon(
                    tab.icon,
                    size: 24,
                    color: _tab == tab ? Colors.white : _PvColors.icon,
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
    return switch (_tab) {
      ComicMenuTab.menu => _buildMainMenu(),
      ComicMenuTab.catalog => _buildCatalog(),
      ComicMenuTab.color => _buildColorTab(),
      ComicMenuTab.settings => _buildSettingsTab(),
      ComicMenuTab.history => _buildHistoryTab(),
      ComicMenuTab.bookmark => _buildBookmarkTab(),
    };
  }

  Widget _buildMainMenu() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvItem(
          icon: Icons.folder_open_rounded,
          title: '文件浏览器',
          onTap: () => _toast('漫画阅读中暂不支持文件浏览器'),
        ),
        _PvItem(
          icon: Icons.collections_bookmark_rounded,
          title: '我的书柜',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        _PvItem(
          icon: Icons.insert_drive_file_rounded,
          title: '开启文件',
          onTap: () => _toast('请回到书架页导入文件'),
        ),
        _PvItem(
          icon: Icons.bookmark_add_rounded,
          title: '插入书签',
          onTap: () => _toast('已记录当前页：${widget.currentLogicalPage + 1}'),
        ),
        _PvItem(
          icon: Icons.folder_special_rounded,
          title: '管理我的最爱',
        ),
        _PvItem(
          icon: Icons.favorite_rounded,
          title: '加入我的最爱',
        ),
        _PvItem(
          icon: Icons.play_circle_outline_rounded,
          title: '开始幻灯片播放',
          onTap: () {
            _update(_settings.copyWith(autoTurn: true));
            Navigator.of(context).maybePop();
          },
        ),
        _PvItem(
          icon: Icons.download_rounded,
          title: '下载管理',
        ),
        _PvItem(
          icon: Icons.zoom_in_rounded,
          title: '对话框放大镜',
        ),
        _PvItem(
          icon: Icons.forward_rounded,
          title: '快速前往',
          onTap: () => setState(() => _tab = ComicMenuTab.history),
        ),
        _PvItem(
          icon: Icons.toc_rounded,
          title: '目次',
          onTap: () => setState(() => _tab = ComicMenuTab.catalog),
        ),
        _PvItem(
          icon: Icons.info_outline_rounded,
          title: 'EXIF',
          onTap: () => setState(() => _tab = ComicMenuTab.catalog),
        ),
        _PvItem(
          icon: Icons.share_rounded,
          title: '分享',
        ),
        _PvItem(
          icon: Icons.print_rounded,
          title: '打印',
        ),
        _PvItem(
          icon: Icons.delete_outline_rounded,
          title: '删除书本',
          onTap: widget.onCloseBook,
        ),
        _PvItem(
          icon: Icons.close_rounded,
          title: '关闭',
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildCatalog() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvInfoRow(label: '书名', value: widget.bookTitle),
        _PvInfoRow(label: '路径', value: widget.bookPath, small: true),
        _PvInfoRow(label: '总页数', value: '${widget.pageCount}'),
        _PvInfoRow(label: '当前屏数', value: '${widget.spreadCount}'),
        _PvInfoRow(label: '当前页', value: '${widget.currentLogicalPage + 1}'),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvInfoRow(label: '当前进度', value: '第 ${widget.currentLogicalPage + 1} 页'),
        _PvItem(
          icon: Icons.first_page_rounded,
          title: '跳到第一页',
          onTap: () {
            widget.onJumpToPage(0);
            Navigator.of(context).maybePop();
          },
        ),
        _PvItem(
          icon: Icons.last_page_rounded,
          title: '跳到最后一页',
          onTap: () {
            widget.onJumpToPage(widget.pageCount - 1);
            Navigator.of(context).maybePop();
          },
        ),
        _PvItem(
          icon: Icons.skip_previous_rounded,
          title: '前进 10 页',
          onTap: () {
            widget.onJumpToPage(widget.currentLogicalPage + 10);
            Navigator.of(context).maybePop();
          },
        ),
        _PvItem(
          icon: Icons.skip_next_rounded,
          title: '后退 10 页',
          onTap: () {
            widget.onJumpToPage(widget.currentLogicalPage - 10);
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }

  Widget _buildBookmarkTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        _PvInfoRow(label: '目前无书签数据', value: ''),
      ],
    );
  }

  // ---------------------------------------------------------- 调整颜色

  Widget _buildColorTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PvSwitchItem(
          icon: Icons.settings_rounded,
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
          title: '色相 / 彩度',
          enabled: _colorMasterOn,
          value: _settings.saturation,
          min: 0,
          max: 2,
          divisions: 40,
          valueLabel: '${(_settings.saturation * 100).round()}%',
          onChanged: (value) =>
              _update(_settings.copyWith(saturation: value)),
        ),
        _PvSwitchItem(
          icon: Icons.invert_colors_rounded,
          title: '反相',
          enabled: _colorMasterOn,
          value: _settings.invert,
          onChanged: (value) => _update(_settings.copyWith(invert: value)),
        ),
        _PvSwitchItem(
          icon: Icons.gradient_rounded,
          title: '灰阶',
          enabled: _colorMasterOn,
          value: _settings.grayscale,
          onChanged: (value) => _update(_settings.copyWith(grayscale: value)),
        ),
        _PvSwitchItem(
          icon: Icons.filter_vintage_rounded,
          title: '复古色调',
          enabled: _colorMasterOn,
          value: _settings.sepia,
          onChanged: (value) => _update(_settings.copyWith(sepia: value)),
        ),
        _PvSwitchItem(
          icon: Icons.details_rounded,
          title: '图像锐化',
          enabled: false,
          value: false,
          subtitle: '暂不支持',
          onChanged: (_) {},
        ),
        _PvSliderItem(
          icon: Icons.blur_on_rounded,
          title: '高斯模糊',
          enabled: _colorMasterOn,
          value: _settings.blur,
          min: 0,
          max: 12,
          divisions: 12,
          valueLabel: _settings.blur.toStringAsFixed(1),
          onChanged: (value) => _update(_settings.copyWith(blur: value)),
        ),
        _PvSwitchItem(
          icon: Icons.crop_rounded,
          title: '手工裁切',
          enabled: false,
          value: false,
          subtitle: '暂不支持',
          onChanged: (_) {},
        ),
        _PvSwitchItem(
          icon: Icons.border_clear_rounded,
          title: '自动侦测白边',
          enabled: true,
          value: _settings.cropBorders,
          useSliderStyle: true,
          onChanged: (value) => _update(_settings.copyWith(cropBorders: value)),
        ),
        _PvSwitchItem(
          icon: Icons.colorize_rounded,
          title: '自动上色',
          enabled: false,
          value: false,
          subtitle: '暂不支持',
          onChanged: (_) {},
        ),
        _PvSwitchItem(
          icon: Icons.auto_awesome_rounded,
          title: '自动调整亮度对比',
          enabled: _colorMasterOn,
          value: _settings.autoLevels,
          onChanged: (value) => _update(_settings.copyWith(autoLevels: value)),
        ),
        _PvSwitchItem(
          icon: Icons.grid_on_rounded,
          title: '去块滤镜',
          enabled: false,
          value: false,
          subtitle: '暂不支持',
          onChanged: (_) {},
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
          title: '开页方向',
          values: ComicPageDirection.values,
          labelOf: (value) => switch (value) {
            ComicPageDirection.vertical => '由上至下',
            ComicPageDirection.horizontalLeft => '由左至右',
            ComicPageDirection.horizontalRight => '由右至左',
          },
          value: _settings.direction,
          onChanged: (value) =>
              _update(_settings.copyWith(direction: value)),
        ),
        _PvPickerItem<ComicScreenOrientation>(
          icon: Icons.smartphone_rounded,
          title: '屏幕方向',
          values: ComicScreenOrientation.values,
          labelOf: (value) => value.label,
          value: _settings.screenOrientation,
          onChanged: (value) =>
              _update(_settings.copyWith(screenOrientation: value)),
        ),
        _PvPickerItem<ComicFitMode>(
          icon: Icons.fit_screen_rounded,
          title: '缩放方式',
          values: ComicFitMode.values,
          labelOf: (value) => value.label,
          value: _settings.fitMode,
          onChanged: (value) => _update(_settings.copyWith(fitMode: value)),
        ),
        _PvPickerItem<ComicInterfaceTheme>(
          icon: Icons.brightness_6_rounded,
          title: '界面主题',
          values: ComicInterfaceTheme.values,
          labelOf: (value) => value.label,
          value: _settings.interfaceTheme,
          onChanged: (value) =>
              _update(_settings.copyWith(interfaceTheme: value)),
        ),
        _PvPickerItem<ComicPageLayout>(
          icon: Icons.auto_stories_rounded,
          title: '阅读模式',
          values: ComicPageLayout.values,
          labelOf: (value) => switch (value) {
            ComicPageLayout.single => '单页模式',
            ComicPageLayout.doublePage => '双页模式',
            ComicPageLayout.auto => '自动识别',
          },
          value: _settings.layout,
          onChanged: (value) => _update(_settings.copyWith(layout: value)),
        ),
        _PvSliderItem(
          icon: Icons.brightness_low_rounded,
          title: '背光控制',
          enabled: true,
          value: _settings.backlight,
          min: 20,
          max: 100,
          divisions: 16,
          valueLabel: _settings.backlight.round().toString(),
          onChanged: (value) => _update(_settings.copyWith(backlight: value)),
        ),
        _PvSliderItem(
          icon: Icons.nightlight_rounded,
          title: '过滤蓝光',
          enabled: true,
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
          title: '页面边界',
          enabled: true,
          value: _settings.pageGap,
          min: 0,
          max: 40,
          divisions: 20,
          valueLabel: _settings.pageGap.round().toString(),
          onChanged: (value) => _update(_settings.copyWith(pageGap: value)),
        ),
        _PvSwitchItem(
          icon: Icons.note_add_outlined,
          title: '插入空白页作为封里',
          enabled: true,
          value: _settings.blankFirstPage,
          onChanged: (value) =>
              _update(_settings.copyWith(blankFirstPage: value)),
        ),
        _PvSwitchItem(
          icon: Icons.content_cut_rounded,
          title: '自动分割双页',
          enabled: true,
          value: _settings.splitDoublePage,
          onChanged: (value) =>
              _update(_settings.copyWith(splitDoublePage: value)),
        ),
        _PvSwitchItem(
          icon: Icons.touch_app_rounded,
          title: '点击区域翻页',
          enabled: true,
          value: _settings.tapToTurn,
          onChanged: (value) => _update(_settings.copyWith(tapToTurn: value)),
        ),
        _PvSwitchItem(
          icon: Icons.slideshow_rounded,
          title: '自动翻页',
          enabled: true,
          value: _settings.autoTurn,
          onChanged: (value) => _update(_settings.copyWith(autoTurn: value)),
        ),
        if (_settings.autoTurn)
          _PvSliderItem(
            icon: Icons.timer_rounded,
            title: '翻页间隔',
            enabled: true,
            value: _settings.autoTurnSeconds.toDouble(),
            min: 2,
            max: 30,
            divisions: 28,
            valueLabel: '${_settings.autoTurnSeconds} 秒',
            onChanged: (value) => _update(
              _settings.copyWith(autoTurnSeconds: value.round()),
            ),
          ),
        _PvInfoRow(label: '显示信息', value: ''),
        _PvInfoRow(label: '问题回报', value: ''),
      ],
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// ---------------------------------------------------------------- 列表项

/// 图标 + 标题 + 右侧箭头/文本 的可点条目。
class _PvItem extends StatelessWidget {
  const _PvItem({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _PvColors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _PvColors.icon),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _PvColors.text,
                  fontSize: 16,
                  height: 1.2,
                ),
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
    required this.title,
    required this.values,
    required this.labelOf,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
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
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _PvColors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: _PvColors.icon),
                const SizedBox(width: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: _PvColors.text,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    labelOf(value),
                    style: const TextStyle(
                      color: _PvColors.subText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: _PvColors.subText,
                    size: 22,
                  ),
                ],
              ),
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
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.subtitle,
    this.useSliderStyle = false,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? subtitle;
  final bool useSliderStyle;

  @override
  Widget build(BuildContext context) {
    final activeColor = useSliderStyle
        ? const Color(0xFFE45B5B)
        : const Color(0xFF7C87E8);
    return Container(
      height: subtitle == null ? 56 : 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _PvColors.divider)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: enabled ? _PvColors.icon : const Color(0x4DFFFFFF),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? _PvColors.text
                        : const Color(0x80FFFFFF),
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0x66FFFFFF),
                      fontSize: 11,
                    ),
                  ),
              ],
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
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _PvColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled ? _PvColors.icon : const Color(0x4DFFFFFF),
              ),
              const SizedBox(width: 18),
              Text(
                title,
                style: TextStyle(
                  color: enabled ? _PvColors.text : const Color(0x80FFFFFF),
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: _PvColors.subText,
                  fontSize: 13,
                ),
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
  const _PvInfoRow({
    required this.label,
    required this.value,
    this.small = false,
  });

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _PvColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _PvColors.text, fontSize: 16),
          ),
          const Spacer(),
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: small ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _PvColors.subText,
                  fontSize: small ? 11 : 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
