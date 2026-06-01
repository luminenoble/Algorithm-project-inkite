import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';

/// 监听 `users.unlocks.magicInk`，未解锁时不渲染任何内容。
///
/// 抽出一层是为了让调用方（gallery / editor）零成本接入：
/// 解锁逻辑统一在此读，UI 分量由 [builder] 自定义。
class MagicInkGate extends StatelessWidget {
  const MagicInkGate({super.key, required this.builder});

  /// `unlocked == true` 时渲染对应 UI；false 时返回 `SizedBox.shrink`。
  final Widget Function(BuildContext, bool unlocked) builder;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, snap) {
        final unlocked = snap.data?.unlocks.magicInk ?? false;
        return builder(context, unlocked);
      },
    );
  }
}

/// 展览厅顶部金箔横幅：`magicInk` 解锁后显示。
///
/// `fronted-design.md` §8.3 / §9 设想 magicInk 解锁会带金箔点缀 + 笔触特效，
/// 本版静态横幅是入门版，动效（`unlock_gold.json` 金箔展开）留到 R12 之后。
class MagicInkBanner extends StatelessWidget {
  const MagicInkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MagicInkGate(
      builder: (context, unlocked) {
        if (!unlocked) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x1FB8893A),
                  Color(0x0FB8893A),
                ],
              ),
              border: Border.all(color: const Color(0xFFB8893A)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_fix_high,
                    size: 18, color: Color(0xFFB8893A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '魔法墨水已激活',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2622),
                    ),
                  ),
                ),
                Text(
                  '藏品边缘已镶金箔',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B6258)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 编辑器 AppBar 用的紧凑金箔徽章。
class MagicInkChip extends StatelessWidget {
  const MagicInkChip({super.key});

  @override
  Widget build(BuildContext context) {
    return MagicInkGate(
      builder: (context, unlocked) {
        if (!unlocked) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFB8893A).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFFB8893A)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_fix_high,
                  size: 12, color: Color(0xFFB8893A)),
              SizedBox(width: 4),
              Text(
                '魔法墨水',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB8893A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
