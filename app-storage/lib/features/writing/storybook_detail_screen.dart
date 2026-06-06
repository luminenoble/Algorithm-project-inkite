import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/models/storybook.dart';
import '../../data/repositories/storybook_repository.dart';
import '../../data/repositories/story_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/motion.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import 'widgets/move_story_sheet.dart';

/// T6.3 — 故事书内部屏 · 类文件树按章节聚合（`docs/next-design-detailed.md` §5.2）。
///
/// 折纸箱 = 章节（行聚合），纸鸟 = 文章 + 草稿/已发布状态徽记。复用
/// `fronted-design.md` §5 的折纸文件树造型，分组维度从「草稿/已发布」升级为
/// 「故事书 → 章节」。
class StorybookDetailScreen extends StatefulWidget {
  const StorybookDetailScreen({super.key, required this.storybookId});

  final String storybookId;

  @override
  State<StorybookDetailScreen> createState() => _StorybookDetailScreenState();
}

class _StorybookDetailScreenState extends State<StorybookDetailScreen> {
  /// 折叠起来的章节名集合（默认全展开）。
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    return StreamBuilder<Storybook?>(
      stream:
          StorybookRepository.instance.watchById(widget.storybookId),
      builder: (context, bookSnap) {
        final book = bookSnap.data;
        final title = book?.title ?? '故事书';
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/writing/storybooks'),
            ),
            title: Text('《$title》'),
            actions: [
              TextButton.icon(
                onPressed: book == null ? null : () => _newChapter(book),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('新建章节'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _writeStory(kDefaultChapter),
            icon: const Icon(Icons.edit),
            label: const Text('写故事'),
          ),
          body: StreamBuilder<List<Story>>(
            stream: uid == null
                ? const Stream<List<Story>>.empty()
                : StoryRepository.instance
                    .streamByStorybook(widget.storybookId, authorId: uid),
            builder: (context, storySnap) {
              if (storySnap.hasError) {
                return _IndexHint(error: storySnap.error!);
              }
              if (storySnap.connectionState == ConnectionState.waiting &&
                  !storySnap.hasData) {
                return const Center(child: BrushLoading());
              }
              final stories = storySnap.data ?? const <Story>[];
              return _Tree(
                book: book,
                stories: stories,
                collapsed: _collapsed,
                onToggle: (chapter) => setState(() {
                  if (!_collapsed.remove(chapter)) _collapsed.add(chapter);
                }),
                onWrite: _writeStory,
                onMove: _moveStory,
                onDelete: _deleteStory,
                onPublish: _publishStory,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _newChapter(Storybook book) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建章节'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '章节名'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (book.chapterOrder.contains(name)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('该章节已存在')));
      return;
    }
    await StorybookRepository.instance
        .setChapterOrder(book.id, [...book.chapterOrder, name]);
  }

  void _writeStory(String chapter) {
    // 写入当前故事书 + 指定章节；编辑器据 fromStorybook 返回本屏（§3.2 调用约定）。
    context.go('/writing/editor', extra: {
      'mode': 'free',
      'storybookId': widget.storybookId,
      'chapterName': chapter,
      'fromStorybook': widget.storybookId,
    });
  }

  Future<void> _moveStory(Story story) async {
    await showMoveStorySheet(context, story);
  }

  Future<void> _publishStory(Story story) async {
    try {
      await StoryRepository.instance.update(
        story.id,
        visibility: StoryVisibility.public,
        publishedToSquare: true,
      );
      await StorybookRepository.instance.touch(widget.storybookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已发布到广场')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发布失败：$e')));
    }
  }

  Future<void> _deleteStory(Story story) async {
    final skin = context.skin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除故事？'),
        content: Text('「${story.title.isEmpty ? '（无标题）' : story.title}」将永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: skin.accentSeal),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await StoryRepository.instance.delete(story.id);
      await StorybookRepository.instance.touch(widget.storybookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}

class _Tree extends StatelessWidget {
  const _Tree({
    required this.book,
    required this.stories,
    required this.collapsed,
    required this.onToggle,
    required this.onWrite,
    required this.onMove,
    required this.onDelete,
    required this.onPublish,
  });

  final Storybook? book;
  final List<Story> stories;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onWrite;
  final ValueChanged<Story> onMove;
  final ValueChanged<Story> onDelete;
  final ValueChanged<Story> onPublish;

  List<String> _orderedChapters() {
    final present = <String, DateTime>{};
    for (final s in stories) {
      final c = s.chapterName.isEmpty ? kDefaultChapter : s.chapterName;
      final t = s.createdAt ?? DateTime.now();
      final cur = present[c];
      if (cur == null || t.isBefore(cur)) present[c] = t;
    }
    final ordered = <String>[];
    for (final c in book?.chapterOrder ?? const <String>[]) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    final rest = present.keys.where((c) => !ordered.contains(c)).toList()
      ..sort((a, b) => present[a]!.compareTo(present[b]!));
    ordered.addAll(rest);
    if (ordered.isEmpty) ordered.add(kDefaultChapter);
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final chapters = _orderedChapters();
    final byChapter = <String, List<Story>>{};
    for (final s in stories) {
      final c = s.chapterName.isEmpty ? kDefaultChapter : s.chapterName;
      byChapter.putIfAbsent(c, () => []).add(s);
    }
    for (final list in byChapter.values) {
      list.sort((a, b) {
        final ta = a.createdAt ?? DateTime.now();
        final tb = b.createdAt ?? DateTime.now();
        return ta.compareTo(tb);
      });
    }

    if (stories.isEmpty && chapters.length <= 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(OrigamiGlyph.emptyPaper, size: 56, color: skin.inkFaint),
            const SizedBox(height: 14),
            Text('这本故事书还是空的',
                style: TextStyle(color: skin.inkSecondary)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => onWrite(kDefaultChapter),
              icon: const Icon(Icons.edit),
              label: const Text('写第一篇'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final chapter in chapters)
          _ChapterSection(
            chapter: chapter,
            stories: byChapter[chapter] ?? const [],
            collapsed: collapsed.contains(chapter),
            onToggle: () => onToggle(chapter),
            onWrite: () => onWrite(chapter),
            onMove: onMove,
            onDelete: onDelete,
            onPublish: onPublish,
          ),
      ],
    );
  }
}

/// 章节行（折纸箱）+ 其下纸鸟故事节点。
class _ChapterSection extends StatelessWidget {
  const _ChapterSection({
    required this.chapter,
    required this.stories,
    required this.collapsed,
    required this.onToggle,
    required this.onWrite,
    required this.onMove,
    required this.onDelete,
    required this.onPublish,
  });

  final String chapter;
  final List<Story> stories;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onWrite;
  final ValueChanged<Story> onMove;
  final ValueChanged<Story> onDelete;
  final ValueChanged<Story> onPublish;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                // 盒盖开合：展开 progress=1 / 折叠 progress=0（§5.2/§10）。
                OrigamiIcon(
                  OrigamiGlyph.box,
                  size: 24,
                  color: skin.inkPrimary,
                  progress: collapsed ? 0.0 : 1.0,
                ),
                const SizedBox(width: 10),
                Text(
                  chapter,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text('${stories.length}',
                    style:
                        TextStyle(fontSize: 12, color: skin.inkSecondary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: '在本章写故事',
                  color: skin.inkSecondary,
                  onPressed: onWrite,
                ),
                Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 18,
                  color: skin.inkSecondary,
                ),
              ],
            ),
          ),
        ),
        // 子项 durFold 高度展开（§10 速查表）。
        AnimatedSize(
          duration: context.motion.scale(Motion.durFold),
          curve: Motion.curveFold,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 6),
                  child: Column(
                    children: [
                      if (stories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('（空章节）',
                                style: TextStyle(
                                    fontSize: 12, color: skin.inkFaint)),
                          ),
                        ),
                      for (final s in stories)
                        StoryBirdTile(
                          story: s,
                          onMove: () => onMove(s),
                          onDelete: () => onDelete(s),
                          onPublish: () => onPublish(s),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// 纸鸟故事节点 + 草稿/已发布状态徽记（§5.2）。
class StoryBirdTile extends StatelessWidget {
  const StoryBirdTile({
    super.key,
    required this.story,
    required this.onMove,
    required this.onDelete,
    required this.onPublish,
  });

  final Story story;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onPublish;

  Future<void> _menu(BuildContext context, Offset pos) async {
    final skin = context.skin;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final sel = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy,
        overlay.size.width - pos.dx,
        overlay.size.height - pos.dy,
      ),
      items: [
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        if (!story.publishedToSquare)
          const PopupMenuItem(value: 'publish', child: Text('发布到广场')),
        const PopupMenuItem(value: 'move', child: Text('移动到…')),
        PopupMenuItem(
          value: 'delete',
          child: Text('删除', style: TextStyle(color: skin.accentSeal)),
        ),
      ],
    );
    if (sel == null || !context.mounted) return;
    switch (sel) {
      case 'edit':
        _open(context);
      case 'publish':
        onPublish();
      case 'move':
        onMove();
      case 'delete':
        onDelete();
    }
  }

  void _open(BuildContext context) {
    context.go('/writing/editor', extra: {
      'storyId': story.id,
      'fromStorybook': story.storybookId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onSecondaryTapDown: (d) => _menu(context, d.globalPosition),
      onLongPressStart: (d) => _menu(context, d.globalPosition),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                OrigamiIcon(OrigamiGlyph.bird, size: 20, color: skin.inkSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    story.title.isEmpty ? '（无标题）' : story.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(story: story),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 草稿 / 已发布状态徽记（不再作为分组层级，§5.2）。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final published = story.publishedToSquare;
    if (published) {
      // 已发布用印章意象（accentSeal）。
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrigamiIcon(OrigamiGlyph.seal, size: 13, color: skin.accentSeal),
          const SizedBox(width: 4),
          Text('已发布',
              style: TextStyle(fontSize: 11, color: skin.accentSeal)),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: skin.paperShade,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('草稿',
          style: TextStyle(fontSize: 11, color: skin.inkSecondary)),
    );
  }
}

class _IndexHint extends StatelessWidget {
  const _IndexHint({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: skin.accentSeal, size: 40),
            const SizedBox(height: 12),
            Text('章节加载失败',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '可能是复合索引尚未部署。请执行\nfirebase deploy --only firestore:indexes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: skin.inkSecondary),
            ),
            const SizedBox(height: 8),
            // Firestore 的「需要索引」报错原文含一键建索引的 Console URL。
            SelectableText(
              '$error',
              maxLines: 4,
              style: TextStyle(fontSize: 10, color: skin.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
