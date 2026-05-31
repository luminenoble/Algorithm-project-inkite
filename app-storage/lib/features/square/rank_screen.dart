import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import 'widgets/story_card.dart';

/// 排行榜 `/square/rank`：按 hotScore 降序展示 Top 20。
///
/// 数据流走 `streamSquareFeed(sort: hotScore, limit: 20)`；
/// 每行复用 `StoryCard` 并传入 `rank` 名次。
class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/square'),
        ),
        title: const Text('排行榜'),
      ),
      body: StreamBuilder<List<Story>>(
        stream: StoryRepository.instance.streamSquareFeed(
          sort: SquareSort.hotScore,
          limit: 20,
        ),
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
          final stories = snap.data ?? const [];
          if (stories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '榜单为空\n发布一篇故事即可上榜',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B6258)),
                ),
              ),
            );
          }
          return Column(
            children: [
              const _RankHeader(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => StoryCard(
                    story: stories[i],
                    rank: i + 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankHeader extends StatelessWidget {
  const _RankHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Icon(Icons.emoji_events,
              size: 18, color: Color(0xFFB8893A)),
          const SizedBox(width: 8),
          const Text(
            '按热度排序 · 实时更新',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B6258)),
          ),
          const Spacer(),
          Text(
            'Top 20',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
