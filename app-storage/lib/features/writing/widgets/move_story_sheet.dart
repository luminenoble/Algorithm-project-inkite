import 'package:flutter/material.dart';

import '../../../data/models/story.dart';
import '../../../data/models/storybook.dart';
import '../../../data/repositories/storybook_repository.dart';
import '../../../data/repositories/story_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/brush_loading.dart';

/// 移动故事到其他故事书 / 章节（`docs/next-design-detailed.md` §5.2「移动」交互）。
///
/// 选目标故事书 → 选/输入章节 → `StoryRepository.update(storybookId, chapterName)`
/// + 两端 `StorybookRepository.touch`（让「修改时间排序」准确，§3.2 调用约定）。
Future<void> showMoveStorySheet(BuildContext context, Story story) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MoveSheet(story: story),
  );
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.story});
  final Story story;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  Storybook? _targetBook;
  String? _targetChapter;
  final _newChapterController = TextEditingController();
  bool _moving = false;

  @override
  void dispose() {
    _newChapterController.dispose();
    super.dispose();
  }

  Future<void> _move() async {
    final book = _targetBook;
    if (book == null || _moving) return;
    final chapter = (_newChapterController.text.trim().isNotEmpty)
        ? _newChapterController.text.trim()
        : (_targetChapter ?? kDefaultChapter);

    setState(() => _moving = true);
    final fromBookId = widget.story.storybookId;
    try {
      await StoryRepository.instance.update(
        widget.story.id,
        storybookId: book.id,
        chapterName: chapter,
      );
      // 若移入了新章节，登记到目标书 chapterOrder。
      if (!book.chapterOrder.contains(chapter)) {
        await StorybookRepository.instance
            .setChapterOrder(book.id, [...book.chapterOrder, chapter]);
      }
      await StorybookRepository.instance.touch(book.id);
      if (fromBookId.isNotEmpty && fromBookId != book.id) {
        await StorybookRepository.instance.touch(fromBookId);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已移动到《${book.title}》· $chapter')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _moving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('移动失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    final skin = context.skin;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('移动到…', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (uid == null)
              const Text('请先登录')
            else
              StreamBuilder<List<Storybook>>(
                stream: StorybookRepository.instance.streamMine(uid),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: BrushLoading(size: 28, showSlowHint: false),
                    );
                  }
                  final books = snap.data!;
                  final target = _targetBook ??
                      _firstWhereOrNull(books,
                          (b) => b.id == widget.story.storybookId) ??
                      (books.isNotEmpty ? books.first : null);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('故事书',
                          style: TextStyle(
                              fontSize: 12, color: skin.inkSecondary)),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: target?.id,
                        items: [
                          for (final b in books)
                            DropdownMenuItem(
                              value: b.id,
                              child: Text(b.title),
                            ),
                        ],
                        onChanged: (id) {
                          setState(() {
                            _targetBook =
                                _firstWhereOrNull(books, (b) => b.id == id);
                            _targetChapter = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('章节',
                          style: TextStyle(
                              fontSize: 12, color: skin.inkSecondary)),
                      const SizedBox(height: 6),
                      _ChapterChoice(
                        book: target,
                        selected: _targetChapter,
                        onSelect: (c) => setState(() {
                          _targetChapter = c;
                          _newChapterController.clear();
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newChapterController,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '或输入新章节名',
                        ),
                        onChanged: (_) => setState(() => _targetChapter = null),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: (target == null || _moving)
                              ? null
                              : () {
                                  _targetBook = target;
                                  _move();
                                },
                          child: Text(_moving ? '移动中…' : '移动'),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 章节选择：把目标书已有章节（chapterOrder + 默认章）做成 chips。
class _ChapterChoice extends StatelessWidget {
  const _ChapterChoice({
    required this.book,
    required this.selected,
    required this.onSelect,
  });

  final Storybook? book;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final chapters = <String>{
      kDefaultChapter,
      ...?book?.chapterOrder,
    }.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chapters)
          ChoiceChip(
            label: Text(c),
            selected: selected == c,
            onSelected: (_) => onSelect(c),
          ),
      ],
    );
  }
}

T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
  for (final e in list) {
    if (test(e)) return e;
  }
  return null;
}
