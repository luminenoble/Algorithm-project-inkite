import 'package:flutter/material.dart';

import '../../../data/repositories/like_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/motion.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/origami_icon.dart';
import '../../../widgets/origami_icons.dart';

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

/// 折纸心点赞按钮：选中态填充朱砂，切换时做一次迸放微缩放（§6.3 点赞迸朱砂的轻量版）。
class _LikeIconButton extends StatelessWidget {
  const _LikeIconButton({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return IconButton(
      onPressed: onTap,
      tooltip: liked ? '取消点赞' : '点赞',
      style: IconButton.styleFrom(
        backgroundColor: liked
            ? skin.accentVermilion.withValues(alpha: 0.12)
            : skin.surfaceCard,
      ),
      icon: AnimatedScale(
        scale: liked ? 1.15 : 1.0,
        duration: Motion.durInstant,
        curve: Motion.curveFold,
        child: OrigamiIcon(
          OrigamiGlyph.heart,
          size: 20,
          fill: liked,
          color: liked ? skin.accentVermilion : skin.inkSecondary,
        ),
      ),
    );
  }
}
