import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/repositories/story_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';

/// "我的故事"列表页。
///
/// 用 `StoryRepository.streamMyStories(uid)` 拉取，区分草稿 / 已发布两栏；
/// 支持点击编辑（跳编辑器 + storyId）与删除（带二次确认）。
class MyStoriesScreen extends StatelessWidget {
  const MyStoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/writing'),
          ),
          title: const Text('我的故事'),
        ),
        body: const Center(child: Text('请先登录')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/writing'),
          ),
          title: const Text('我的故事'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '草稿'),
              Tab(text: '已发布'),
            ],
          ),
        ),
        body: StreamBuilder<List<Story>>(
          stream: StoryRepository.instance.streamMyStories(uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: BrushLoading());
            }
            final all = snap.data ?? const [];
            final drafts = all
                .where((s) => s.visibility == StoryVisibility.private)
                .toList(growable: false);
            final published = all
                .where((s) => s.visibility == StoryVisibility.public)
                .toList(growable: false);
            return TabBarView(
              children: [
                _StoryList(stories: drafts, emptyText: '还没有草稿'),
                _StoryList(stories: published, emptyText: '还没有发布的故事'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoryList extends StatelessWidget {
  const _StoryList({required this.stories, required this.emptyText});

  final List<Story> stories;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyText, style: TextStyle(color: context.skin.inkSecondary)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _StoryRow(story: stories[i]),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story});
  final Story story;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除故事？'),
        content: Text('"${story.title}" 将永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.skin.accentSeal),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StoryRepository.instance.delete(story.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Card(
      child: InkWell(
        onTap: () => context.go('/writing/editor', extra: {'storyId': story.id}),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _ModeChip(mode: story.mode),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                story.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: skin.inkSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (story.updatedAt != null)
                    Text(
                      _formatDate(story.updatedAt!),
                      style: TextStyle(fontSize: 12, color: skin.inkSecondary),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: skin.inkSecondary,
                    onPressed: () => context
                        .go('/writing/editor', extra: {'storyId': story.id}),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: skin.accentSeal,
                    onPressed: () => _confirmDelete(context),
                    tooltip: '删除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final StoryMode mode;

  static const _labels = {
    StoryMode.official: '官方',
    StoryMode.free: '自由',
    StoryMode.diary: '日记',
    StoryMode.essay: '随笔',
    StoryMode.fanfic: '同人',
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isOfficial = mode == StoryMode.official;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOfficial ? skin.accentVermilion : skin.paperShade,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _labels[mode] ?? mode.name,
        style: TextStyle(
          fontSize: 11,
          color: isOfficial ? skin.paperHighlight : skin.inkSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
