import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/story.dart';

/// 广场动态卡片：标题 + 作者 + 摘要 + 点赞 / 评论计数。
///
/// 计数字段（`likeCount` / `commentCount`）由 CF 维护，本卡片只渲染；
/// 点击整张卡片跳详情 `/square/story/:id`。
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    this.rank,
  });

  /// 排行榜行可传入名次（1-based），普通广场列表传 null。
  final int? rank;
  final Story story;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFBF8F0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/square/story/${story.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rank != null) ...[
                _RankBadge(rank: rank!),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            story.title.isEmpty ? '（无标题）' : story.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B2622),
                            ),
                          ),
                        ),
                        if (story.mode == StoryMode.official)
                          const _OfficialBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.authorName.isEmpty ? '匿名' : story.authorName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6258),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF2B2622),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _CountChip(
                          icon: Icons.favorite_outline,
                          count: story.likeCount,
                        ),
                        const SizedBox(width: 16),
                        _CountChip(
                          icon: Icons.mode_comment_outlined,
                          count: story.commentCount,
                        ),
                        const Spacer(),
                        if (story.createdAt != null)
                          Text(
                            _formatDate(story.createdAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B6258),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B6258)),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6258)),
        ),
      ],
    );
  }
}

class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFC2410C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '官方',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 名次徽记。Top 3 用朱砂 / 金箔，其余用次墨色。
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final color = switch (rank) {
      1 => const Color(0xFFC2410C),
      2 => const Color(0xFFB8893A),
      3 => const Color(0xFF9A2D1F),
      _ => const Color(0xFFC9C0B2),
    };
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop3 ? color : Colors.transparent,
        border: isTop3 ? null : Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isTop3 ? Colors.white : const Color(0xFF6B6258),
        ),
      ),
    );
  }
}
