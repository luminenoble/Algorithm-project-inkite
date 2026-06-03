import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import '../../widgets/paper_skeleton.dart';
import 'widgets/story_card.dart';

/// 通道广场：实时拉取公开故事，支持 hotScore / newest 排序切换。
///
/// 数据流走 `StoryRepository.streamSquareFeed(sort)`；
/// 点击卡片跳详情 `/square/story/:id`（T3.2）；
/// 右上角入口跳排行榜 `/square/rank`（T3.5）。
class SquareScreen extends StatefulWidget {
  const SquareScreen({super.key});

  @override
  State<SquareScreen> createState() => _SquareScreenState();
}

class _SquareScreenState extends State<SquareScreen> {
  SquareSort _sort = SquareSort.hotScore;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('广场'),
        actions: [
          IconButton(
            tooltip: '排行榜',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.go('/square/rank'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<SquareSort>(
              segments: const [
                ButtonSegment(
                  value: SquareSort.hotScore,
                  label: Text('热门'),
                  icon: Icon(Icons.local_fire_department_outlined),
                ),
                ButtonSegment(
                  value: SquareSort.newest,
                  label: Text('最新'),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (s) => setState(() => _sort = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Story>>(
              stream: StoryRepository.instance.streamSquareFeed(sort: _sort),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const PaperSkeletonList(count: 4, itemHeight: 116);
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OrigamiIcon(OrigamiGlyph.emptyPaper,
                              size: 56, color: skin.inkFaint),
                          const SizedBox(height: 12),
                          Text(
                            '广场暂无故事\n去写作 Tab 发布第一篇吧',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: skin.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: stories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => StoryCard(story: stories[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
