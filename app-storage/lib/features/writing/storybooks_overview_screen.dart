import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/story.dart';
import '../../data/models/storybook.dart';
import '../../data/repositories/storybook_repository.dart';
import '../../data/repositories/story_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import 'storybook_covers.dart';
import 'widgets/cover_picker.dart';

/// T6.2 — 故事书总览屏（`docs/next-design-detailed.md` §5.1）。
///
/// 「我的故事」入口进入；流式网格展示「封面 + 书名 + 时间」，支持创建时间 /
/// 修改时间排序、pin 置顶，以及建/改名/删/换封面。默认书的改名/删除入口不出现。
class StorybooksOverviewScreen extends StatefulWidget {
  const StorybooksOverviewScreen({super.key});

  @override
  State<StorybooksOverviewScreen> createState() =>
      _StorybooksOverviewScreenState();
}

class _StorybooksOverviewScreenState extends State<StorybooksOverviewScreen> {
  StorybookSort _sort = StorybookSort.updatedAt;
  Future<void>? _ensureDefault;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUid;
    // 进总览即惰性确保默认书存在（幂等），让首次使用的用户也至少有一本「未分类」。
    if (uid != null) {
      _ensureDefault = StorybookRepository.instance.getOrCreateDefault(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的故事')),
        body: const Center(child: Text('请先登录')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/writing'),
        ),
        title: const Text('我的故事'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Row(
              children: [
                _SortToggle(
                  sort: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<void>(
        future: _ensureDefault,
        builder: (context, ensureSnap) {
          if (ensureSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: BrushLoading());
          }
          return StreamBuilder<List<Storybook>>(
            stream: StorybookRepository.instance.streamMine(uid, sort: _sort),
            builder: (context, bookSnap) {
              if (bookSnap.hasError) {
                return _IndexHint(error: bookSnap.error!);
              }
              if (bookSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: BrushLoading());
              }
              final books = bookSnap.data ?? const <Storybook>[];
              // 一条 story 流兜底每本书的故事数 + 空态判定（首版不接 storyCount CF）。
              return StreamBuilder<List<Story>>(
                stream: StoryRepository.instance
                    .streamMyStories(uid, limit: 500),
                builder: (context, storySnap) {
                  final stories = storySnap.data ?? const <Story>[];
                  final counts = <String, int>{};
                  for (final s in stories) {
                    counts[s.storybookId] = (counts[s.storybookId] ?? 0) + 1;
                  }
                  return _OverviewBody(
                    books: books,
                    counts: counts,
                    sort: _sort,
                    storyCount: stories.length,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.books,
    required this.counts,
    required this.sort,
    required this.storyCount,
  });

  final List<Storybook> books;
  final Map<String, int> counts;
  final StorybookSort sort;
  final int storyCount;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // 仅一本默认书且毫无故事 → 空态引导。
    final onlyEmptyDefault =
        storyCount == 0 && books.length <= 1 && (books.isEmpty || books.first.isDefault);
    if (onlyEmptyDefault) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(OrigamiGlyph.emptyPaper, size: 64, color: skin.inkFaint),
            const SizedBox(height: 16),
            Text('还没有故事，落笔写第一篇',
                style: TextStyle(color: skin.inkSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/writing'),
              icon: const Icon(Icons.edit),
              label: const Text('去写作'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端每行 3–4 张（§5.1）：按可用宽度推列数。
        final cols = (constraints.maxWidth / 240).floor().clamp(2, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(DesignTokens.pagePadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: DesignTokens.listGap,
            crossAxisSpacing: DesignTokens.listGap,
            childAspectRatio: 0.72,
          ),
          itemCount: books.length + 1,
          itemBuilder: (context, i) {
            if (i == books.length) {
              return const _NewStorybookCard();
            }
            final book = books[i];
            return StorybookCard(
              book: book,
              storyCount: counts[book.id] ?? 0,
              sort: sort,
            );
          },
        );
      },
    );
  }
}

/// 创建时间 / 修改时间排序分段控件（§5.1）。
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.sort, required this.onChanged});
  final StorybookSort sort;
  final ValueChanged<StorybookSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<StorybookSort>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(
          value: StorybookSort.updatedAt,
          label: Text('修改时间'),
          icon: Icon(Icons.update, size: 16),
        ),
        ButtonSegment(
          value: StorybookSort.createdAt,
          label: Text('创建时间'),
          icon: Icon(Icons.schedule, size: 16),
        ),
      ],
      selected: {sort},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// 单张故事书卡片：封面 + 书名 + 时间 + pin 角标 + 右键/长按上下文菜单。
class StorybookCard extends StatelessWidget {
  const StorybookCard({
    super.key,
    required this.book,
    required this.storyCount,
    required this.sort,
  });

  final Storybook book;
  final int storyCount;
  final StorybookSort sort;

  Future<void> _showMenu(BuildContext context, Offset globalPos) async {
    final skin = context.skin;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        overlay.size.width - globalPos.dx,
        overlay.size.height - globalPos.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Text(book.pinned ? '取消置顶' : '置顶'),
        ),
        PopupMenuItem(value: 'cover', child: const Text('换封面')),
        if (!book.isDefault)
          PopupMenuItem(value: 'rename', child: const Text('改名')),
        if (!book.isDefault)
          PopupMenuItem(
            value: 'delete',
            child: Text('删除', style: TextStyle(color: skin.accentSeal)),
          ),
      ],
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case 'pin':
        await StorybookRepository.instance.setPinned(book.id, !book.pinned);
      case 'cover':
        if (context.mounted) await showCoverPicker(context, book);
      case 'rename':
        if (context.mounted) await _rename(context);
      case 'delete':
        if (context.mounted) await _confirmDelete(context);
    }
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: book.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名故事书'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '故事书名'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    try {
      await StorybookRepository.instance.rename(book.id, title);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('改名失败：$e')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final skin = context.skin;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除故事书？'),
        content: Text(
          storyCount > 0
              ? '《${book.title}》含 $storyCount 篇故事。删除后这些故事会移回「未分类 / 未分章」，不会丢失。'
              : '《${book.title}》将被删除。',
        ),
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
    if (ok != true || !context.mounted) return;
    try {
      await StorybookRepository.instance.delete(book.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
      onLongPressStart: (d) => _showMenu(context, d.globalPosition),
      child: Material(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/writing/storybooks/${book.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 金箔细边呼应「藏品 / 书」质感（§5.1）。
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: skin.goldLeaf.withValues(alpha: 0.6),
                        ),
                      ),
                      child: StorybookCover(book: book),
                    ),
                    if (book.pinned)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: _PinBadge(color: skin.accentVermilion),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (book.isDefault)
                          Icon(Icons.inbox_outlined,
                              size: 14, color: skin.inkFaint),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$storyCount 篇 · ${_formatDate(book.timeFor(sort))}',
                      style:
                          TextStyle(fontSize: 12, color: skin.inkSecondary),
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

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 左上角一枚朱砂折角徽记（§5.1）。
    return CustomPaint(
      size: const Size(28, 28),
      painter: _CornerPainter(color: color),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: const EdgeInsets.only(left: 3, top: 2),
          child: Icon(Icons.push_pin,
              size: 11, color: context.skin.paperHighlight),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

/// 「+ 新建故事书」入口卡（虚线框 + 折纸箱图标）。
class _NewStorybookCard extends StatelessWidget {
  const _NewStorybookCard();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return InkWell(
      onTap: () => _showCreateDialog(context),
      borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      child: DottedBorderBox(
        color: skin.inkFaint,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrigamiIcon(OrigamiGlyph.box, size: 40, color: skin.inkSecondary),
              const SizedBox(height: 10),
              Text('新建故事书',
                  style: TextStyle(color: skin.inkSecondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 建书对话框：书名输入 + 选预设封面（§5.1）。
Future<void> _showCreateDialog(BuildContext context) async {
  final uid = AuthService.instance.currentUid;
  if (uid == null) return;
  final controller = TextEditingController();
  String coverAssetId = kCoverPresets.first.id;

  final created = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('新建故事书'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: '故事书名'),
              ),
              const SizedBox(height: 16),
              Text('选个封面',
                  style: TextStyle(
                      fontSize: 12, color: ctx.skin.inkSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCoverPresets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final p = kCoverPresets[i];
                    final selected = p.id == coverAssetId;
                    return GestureDetector(
                      onTap: () => setLocal(() => coverAssetId = p.id),
                      child: Container(
                        width: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? ctx.skin.accentVermilion
                                : ctx.skin.paperShade,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CoverPresetView(preset: p),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );

  if (created != true || !context.mounted) return;
  final title = controller.text.trim();
  final draft = Storybook(
    id: '',
    ownerId: uid,
    title: title.isEmpty ? '新故事书' : title,
    coverUrl: null,
    coverAssetId: coverAssetId,
    chapterOrder: const [kDefaultChapter],
    isDefault: false,
    pinned: false,
    createdAt: null,
    updatedAt: null,
  );
  try {
    final id = await StorybookRepository.instance.create(draft);
    if (!context.mounted) return;
    context.go('/writing/storybooks/$id');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('创建失败：$e')));
  }
}

/// 虚线边框容器（新建卡用）。
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(DesignTokens.radiusCard),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

/// streamMine 报错（多半是复合索引尚未部署）时的友好提示。
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
            Text('故事书列表加载失败',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '可能是复合索引尚未部署。请按 docs/T6 说明执行\nfirebase deploy --only firestore:indexes',
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
