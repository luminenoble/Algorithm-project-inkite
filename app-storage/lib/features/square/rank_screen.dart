import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import 'widgets/story_card.dart';

/// 排行榜 `/square/rank`：按 hotScore 降序展示 Top 20。
///
/// 数据流走 `streamSquareFeed(sort: hotScore, limit: 20)`；
/// 每行复用 `StoryCard` 并传入 `rank` 名次。
class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
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
            return const Center(child: BrushLoading());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败：${snap.error}',
                  style: TextStyle(color: skin.accentSeal),
                ),
              ),
            );
          }
          final stories = snap.data ?? const [];
          if (stories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '榜单为空\n发布一篇故事即可上榜',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: skin.inkSecondary),
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
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          OrigamiIcon(OrigamiGlyph.seal, size: 18, color: skin.goldLeaf),
          const SizedBox(width: 8),
          Text(
            '按热度排序 · 实时更新',
            style: TextStyle(fontSize: 13, color: skin.inkSecondary),
          ),
          const Spacer(),
          Text(
            'Top 20',
            style: TextStyle(
              fontSize: 12,
              color: skin.inkFaint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
