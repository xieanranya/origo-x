// 文件说明：Rex 风格的阅读统计卡（白卡大圆角 + 渐变柱状图 + 热力格 + 大数字）。
// 数据来自 ReadingStatsDao（本周柱状 / 91 天热力 / 汇总），不改内核。
import 'package:flutter/material.dart';

import '../../services/reading/reading_stats_dao.dart';
import 'app_palette.dart';

/// 一屏统计卡：本周阅读（柱状图）+ 阅读热力（格子）+ 今日/累计大数字。
class ReadingStatsCards extends StatefulWidget {
  const ReadingStatsCards({super.key});

  @override
  State<ReadingStatsCards> createState() => _ReadingStatsCardsState();
}

class _ReadingStatsCardsState extends State<ReadingStatsCards> {
  final ReadingStatsDao _dao = ReadingStatsDao();
  Map<String, int> _summary = const {'today': 0, 'week': 0, 'total': 0};
  List<({int weekday, int seconds})> _week = const [];
  Map<String, double> _heat = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        _dao.getSummaryStats(),
        _dao.getWeeklyChartData(),
        _dao.getReadingIntensityHeatmap(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, int>;
        _week = (results[1] as List<Map<String, dynamic>>)
            .map(
              (row) => (
                weekday: (row['day'] as num).toInt(),
                seconds: (row['duration'] as num).toInt(),
              ),
            )
            .toList(growable: false);
        _heat = results[2] as Map<String, double>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeeklyCard(palette: palette, week: _week),
        const SizedBox(height: 14),
        _HeatmapCard(palette: palette, heat: _heat),
        const SizedBox(height: 14),
        _SummaryRow(palette: palette, summary: _summary),
      ],
    );
  }
}

Widget statsCard({required Widget child, required AppPalette palette}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: palette.hairline),
      boxShadow: palette.cardShadow,
    ),
    child: child,
  );
}

/// 本周阅读：大数字 + 七日渐变柱状图。
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.palette, required this.week});

  final AppPalette palette;
  final List<({int weekday, int seconds})> week;

  /// 松绿渐变：底部墨绿压住，向上化到竹青。
  LinearGradient get _barGradient => palette.dark
      ? const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF5E8A76), Color(0xFFB8D5C6)],
        )
      : const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF2F5D50), Color(0xFF8FB8A3)],
        );

  @override
  Widget build(BuildContext context) {
    final totalMinutes = week.fold<int>(0, (sum, e) => sum + e.seconds) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final bigNumber = hours > 0 ? '$hours' : '$minutes';
    final unit = hours > 0 ? '小时' : '分钟';
    final maxSeconds = week.fold<int>(
      0,
      (m, e) => m > e.seconds ? m : e.seconds,
    );
    final todayWeekday = DateTime.now().weekday;
    return statsCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本周阅读',
                style: AppText.groupLabel.copyWith(
                  letterSpacing: 2,
                  color: palette.text2,
                ),
              ),
              const Spacer(),
              Text(
                _weekRangeLabel(),
                style: TextStyle(fontSize: 11.5, color: palette.text3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bigNumber,
                style: TextStyle(
                  fontFamily: AppFont.serif,
                  fontFamilyFallback: AppFont.fallback,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: palette.text,
                ),
              ),
              const SizedBox(width: 5),
              Text(unit, style: TextStyle(fontSize: 13, color: palette.text2)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in week)
                  Expanded(
                    child: _Bar(
                      gradient: _barGradient,
                      heightRatio: maxSeconds <= 0
                          ? 0
                          : (entry.seconds / maxSeconds).clamp(0.06, 1.0),
                      dim: entry.weekday != todayWeekday,
                      label: _weekdayLabel(entry.weekday),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekRangeLabel() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${start.month}月${two(start.day)}-${two(now.month)}.${two(now.day)}';
  }

  String _weekdayLabel(int weekday) => switch (weekday) {
    1 => '一',
    2 => '二',
    3 => '三',
    4 => '四',
    5 => '五',
    6 => '六',
    _ => '日',
  };
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.gradient,
    required this.heightRatio,
    required this.dim,
    required this.label,
  });

  final Gradient gradient;
  final double heightRatio;
  final bool dim;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightRatio,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1,
              color: dim ? palette.text3 : palette.text,
              fontWeight: dim ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阅读热力：近 13 周 GitHub 风格格子，强度映射紫色。
class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.palette, required this.heat});

  final AppPalette palette;
  final Map<String, double> heat;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // 让最后一列以今天结尾：从本周周日往前推 12 周。
    final end = today.add(Duration(days: 7 - today.weekday));
    final start = end.subtract(const Duration(days: 13 * 7 - 1));
    final cells = <({String key, double level})>[];
    for (var i = 0; i < 13 * 7; i++) {
      final date = start.add(Duration(days: i));
      if (date.isAfter(today)) {
        cells.add((key: '', level: -1));
        continue;
      }
      final key =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      cells.add((key: key, level: heat[key] ?? 0));
    }
    return statsCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读热力',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.text2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 7 * 15,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var w = 0; w < 13; w++)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: _heatCell(cells[w * 7 + d], palette),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatCell(({String key, double level}) cell, AppPalette palette) {
    final base = palette.fill;
    Color color;
    if (cell.level < 0) {
      color = Colors.transparent;
    } else if (cell.level <= 0) {
      color = base;
    } else {
      color = Color.lerp(
        base,
        palette.pine,
        0.25 + 0.75 * cell.level,
      )!;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// 今日 / 本周 / 累计 大数字行。
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.palette, required this.summary});

  final AppPalette palette;
  final Map<String, int> summary;

  @override
  Widget build(BuildContext context) {
    String label(String key) {
      final minutes = (summary[key] ?? 0) ~/ 60;
      if (minutes < 60) return '$minutes 分钟';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '$h 小时' : '$h 小时 $m 分';
    }

    Widget block(String title, String value) => Expanded(
      child: statsCard(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppText.caption.copyWith(
                letterSpacing: 1.5,
                color: palette.text2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFont.serif,
                fontFamilyFallback: AppFont.fallback,
                fontSize: 17,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: palette.text,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        block('今日', label('today')),
        const SizedBox(width: 10),
        block('本周', label('week')),
        const SizedBox(width: 10),
        block('累计', label('total')),
      ],
    );
  }
}
