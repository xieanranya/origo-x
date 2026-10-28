// 文件说明：书架顶部「继续阅读」卡片：小封面 + 书名 + 已读百分比 + 进度条 + 继续按钮。
// 只在存在 0 < 进度 < 1 的最近阅读书籍时渲染。
import 'package:flutter/material.dart';

import '../shell/app_palette.dart';
import 'cover_art.dart';

class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.coverPath,
    this.onTap,
  });

  final String title;

  /// 例如「读到 第 812 章」或「已读 37%」。
  final String subtitle;

  /// 0..1。
  final double progress;

  final String? coverPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final percent = (progress.clamp(0.0, 1.0) * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: palette.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 60,
                    child: CoverArt(
                      title: title,
                      path: coverPath,
                      radius: 7,
                      glyphSize: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.text3),
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: palette.fill,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      '继续 · $percent%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
