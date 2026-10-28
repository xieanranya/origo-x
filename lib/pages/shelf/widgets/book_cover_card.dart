// 文件说明：书架封面卡片（3:4 封面 + 书名 + 作者 + 右下角进度角标 + 未读红点）。
// 封面画法统一走 CoverArt（有图用图，没图按书名生成固定渐变 + 首字）。
import 'package:flutter/material.dart';

import '../shell/app_palette.dart';
import 'cover_art.dart';

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.title,
    this.author,
    this.progress,
    this.badgeText,
    this.coverPath,
    this.showUnreadDot = false,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? author;

  /// 0..1，null 表示没有进度概念（例如书源书籍）。
  final double? progress;

  /// 覆盖默认角标文案（默认按 [progress] 显示百分比或「已读完」）。
  final String? badgeText;

  /// 本地封面文件路径；为空或读取失败时用渐变占位。
  final String? coverPath;

  /// 未读红点。
  final bool showUnreadDot;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final value = progress;
    final done = value != null && value >= 0.995;
    final badge =
        badgeText ??
        (value == null ? null : (done ? '已读完' : '${(value * 100).round()}%'));

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.cover),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                boxShadow: palette.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(
                      title: title,
                      path: coverPath,
                      radius: AppRadius.cover,
                      glyphSize: 34,
                    ),
                    // 底部 24px 渐隐，保证右下角角标可读。
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0x66000000)],
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: done
                                ? Colors.white.withValues(alpha: 0.92)
                                : Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: done
                                  ? const Color(0xFF333333)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (showUnreadDot)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bookName.copyWith(color: palette.text),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              (author == null || author!.trim().isEmpty)
                  ? '未知作者'
                  : author!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bookAuthor.copyWith(color: palette.text3),
            ),
          ),
        ],
      ),
    );
  }
}
