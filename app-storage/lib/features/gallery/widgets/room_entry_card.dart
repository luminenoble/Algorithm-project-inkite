import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/skin_controller.dart';
import '../../../widgets/origami_icon.dart';
import '../../../widgets/origami_icons.dart';
import '../zen_garden_screen.dart';

/// 主题房间入口卡片：禅意花园。
///
/// 已解锁（`users.unlocks.rooms` 含 `zen_garden`）→ 金箔描边 + 可点击；
/// 未解锁 → 灰化 + 锁形 + 解锁条件文案，点击也能进（详情屏内部会渲染锁定态）。
class RoomEntryCard extends StatelessWidget {
  const RoomEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, snap) {
        final unlocked =
            snap.data?.unlocks.rooms.contains(ZenGardenScreen.roomId) ?? false;
        return _Card(unlocked: unlocked);
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.unlocked});
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final color = unlocked ? skin.goldLeaf : skin.inkFaint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/gallery/room/zen-garden'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: unlocked ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? skin.goldLeaf.withValues(alpha: 0.12)
                        : skin.paperShade,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: unlocked
                      ? Icon(Icons.spa_outlined, size: 28, color: skin.goldLeaf)
                      : OrigamiIcon(OrigamiGlyph.lock,
                          size: 26, color: skin.inkSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '禅意花园',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: skin.inkPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (unlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: skin.goldLeaf,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '已解锁',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: skin.paperHighlight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unlocked ? '主题房间 · 沙纹石景' : '完成首个官方挑战即可解锁',
                        style: TextStyle(fontSize: 12, color: skin.inkSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: unlocked ? skin.inkPrimary : skin.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
