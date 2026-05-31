import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import 'widgets/like_button.dart';

/// 故事详情页 `/square/story/:id`。
///
/// 用 `watchById` 实时拿数据；CF 改 `likeCount`/`commentCount` 后会自动刷新。
/// 点赞按钮（T3.3）与评论区（T3.4）以 sliver 形式挂在正文之下。
class StoryDetailScreen extends StatelessWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/square'),
        ),
        title: const Text('故事'),
      ),
      body: StreamBuilder<Story?>(
        stream: StoryRepository.instance.watchById(storyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败：${snap.error}',
                  style: const TextStyle(color: Color(0xFF9A2D1F)),
                ),
              ),
            );
          }
          final story = snap.data;
          if (story == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '故事不存在或已被删除',
                  style: TextStyle(color: Color(0xFF6B6258)),
                ),
              ),
            );
          }
          return _DetailBody(story: story);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        _Header(story: story),
        const SizedBox(height: 20),
        if (story.mode == StoryMode.official && story.words != null) ...[
          _ChallengeWords(words: story.words!),
          const SizedBox(height: 20),
        ],
        SelectableText(
          story.body,
          style: const TextStyle(
            fontSize: 16,
            height: 1.75,
            color: Color(0xFF2B2622),
          ),
        ),
        const SizedBox(height: 24),
        _Stats(story: story),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFFC9C0B2)),
        const SizedBox(height: 8),
        const _CommentsPlaceholder(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (story.mode == StoryMode.official)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2410C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '官方挑战',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                story.title.isEmpty ? '（无标题）' : story.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B2622),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.person_outline,
                size: 14, color: Color(0xFF6B6258)),
            const SizedBox(width: 4),
            Text(
              story.authorName.isEmpty ? '匿名' : story.authorName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B6258)),
            ),
            const SizedBox(width: 12),
            if (story.createdAt != null)
              Text(
                _formatDate(story.createdAt!),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6258)),
              ),
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ChallengeWords extends StatelessWidget {
  const _ChallengeWords({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F0),
        border: Border.all(color: const Color(0xFFC9C0B2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              size: 16, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          const Text(
            '挑战词',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B6258)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: words
                  .map((w) => Chip(
                        label: Text(w),
                        backgroundColor: const Color(0xFFF5F1E8),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LikeButton(storyId: story.id),
        const SizedBox(width: 8),
        Text(
          '${story.likeCount}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF2B2622)),
        ),
        const SizedBox(width: 24),
        const Icon(Icons.mode_comment_outlined,
            size: 18, color: Color(0xFF6B6258)),
        const SizedBox(width: 6),
        Text(
          '${story.commentCount}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF2B2622)),
        ),
        const Spacer(),
        Text(
          '热度 ${story.hotScore.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6258)),
        ),
      ],
    );
  }
}

/// T3.4 评论区将替换此占位。
class _CommentsPlaceholder extends StatelessWidget {
  const _CommentsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '评论区（T3.4 待接）',
        style: TextStyle(color: Color(0xFF6B6258)),
      ),
    );
  }
}
