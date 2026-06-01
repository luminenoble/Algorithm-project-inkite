import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/auth_service.dart';
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
        final unlocked = snap.data?.unlocks.rooms
                .contains(ZenGardenScreen.roomId) ??
            false;
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
    final color = unlocked
        ? const Color(0xFFB8893A)
        : const Color(0xFFC9C0B2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: const Color(0xFFFBF8F0),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/gallery/room/zen-garden'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color,
                width: unlocked ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? const Color(0xFFB8893A).withValues(alpha: 0.12)
                        : const Color(0xFFE7E0D0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    unlocked ? Icons.spa_outlined : Icons.lock_outline,
                    size: 28,
                    color: unlocked
                        ? const Color(0xFFB8893A)
                        : const Color(0xFF6B6258),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '禅意花园',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B2622),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (unlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB8893A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '已解锁',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unlocked ? '主题房间 · 沙纹石景' : '完成首个官方挑战即可解锁',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6258),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: unlocked
                      ? const Color(0xFF2B2622)
                      : const Color(0xFFC9C0B2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
