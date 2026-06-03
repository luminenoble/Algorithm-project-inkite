import 'package:flutter/material.dart';

import '../../../data/models/story_comment.dart';
import '../../../data/repositories/comment_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/brush_loading.dart';
import '../../../widgets/origami_icon.dart';
import '../../../widgets/origami_icons.dart';

/// 评论区：列表 + 输入框。
///
/// 列表走 `CommentRepository.watchComments`，最新在前；
/// 提交走 `add(StoryComment(...))`，`authorName` 取自当前用户档案；
/// 自己的评论可删（弹确认）。`commentCount` 由 CF 维护。
class CommentSection extends StatefulWidget {
  const CommentSection({super.key, required this.storyId});

  final String storyId;

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再评论')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final profile = await UserRepository.instance.getProfile(uid);
      final authorName = profile?.displayName ?? '匿名';
      await CommentRepository.instance.add(
        widget.storyId,
        StoryComment(
          id: '',
          authorId: uid,
          authorName: authorName,
          text: text,
          createdAt: null,
        ),
      );
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('评论失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final myUid = AuthService.instance.currentUid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '评论',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _InputBar(
          controller: _controller,
          submitting: _submitting,
          onSubmit: _submit,
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<StoryComment>>(
          stream: CommentRepository.instance.watchComments(widget.storyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: BrushLoading(size: 36),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '评论加载失败：${snap.error}',
                  style: TextStyle(color: skin.accentSeal),
                ),
              );
            }
            final list = snap.data ?? const [];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      OrigamiIcon(OrigamiGlyph.emptyPaper,
                          size: 40, color: skin.inkFaint),
                      const SizedBox(height: 8),
                      Text(
                        '还没有评论，来留下第一条吧',
                        style: TextStyle(color: skin.inkSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final c in list)
                  _CommentRow(
                    storyId: widget.storyId,
                    comment: c,
                    isMine: c.authorId == myUid,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '说点什么……',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: submitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: submitting
              ? BrushLoading(
                  size: 16,
                  showSlowHint: false,
                  color: skin.paperHighlight,
                )
              : const Text('发送'),
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.storyId,
    required this.comment,
    required this.isMine,
  });

  final String storyId;
  final StoryComment comment;
  final bool isMine;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.skin.accentSeal,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CommentRepository.instance.delete(storyId, comment.id);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: skin.paperShade,
            child: Text(
              comment.authorName.isEmpty
                  ? '?'
                  : comment.authorName.characters.first,
              style: TextStyle(fontSize: 13, color: skin.inkPrimary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName.isEmpty ? '匿名' : comment.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: skin.inkPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment.createdAt != null)
                      Text(
                        _formatDate(comment.createdAt!),
                        style: TextStyle(fontSize: 11, color: skin.inkSecondary),
                      ),
                    const Spacer(),
                    if (isMine)
                      InkWell(
                        onTap: () => _confirmDelete(context),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: skin.accentSeal,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: skin.inkPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
