import 'package:flutter/material.dart';

import '../../../data/repositories/like_repository.dart';
import '../../../services/auth_service.dart';

/// 点赞按钮：`watchHasLiked` 驱动选中态，点按调 `toggle`。
///
/// `likeCount` 由 CF 维护，本组件不负责显示——详情页 / 卡片直接读 `story.likeCount`，
/// Stream 自动反映 1–2 秒后的变化。
///
/// 未登录用户按下会 SnackBar 提示。
class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      return _LikeIconButton(
        liked: false,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后再点赞')),
        ),
      );
    }
    return StreamBuilder<bool>(
      stream: LikeRepository.instance.watchHasLiked(storyId, uid),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return _LikeIconButton(
          liked: liked,
          onTap: () async {
            try {
              await LikeRepository.instance.toggle(storyId, uid);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('操作失败：$e')),
              );
            }
          },
        );
      },
    );
  }
}

class _LikeIconButton extends StatelessWidget {
  const _LikeIconButton({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: liked ? '取消点赞' : '点赞',
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_outline,
        color: liked ? const Color(0xFFC2410C) : const Color(0xFF6B6258),
      ),
      style: IconButton.styleFrom(
        backgroundColor: liked
            ? const Color(0xFFC2410C).withValues(alpha: 0.12)
            : const Color(0xFFFBF8F0),
      ),
    );
  }
}
