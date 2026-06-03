import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';

/// 禅意花园主题房间 `/gallery/room/zen-garden`。
///
/// 进入条件：`users/{uid}.unlocks.rooms` 包含 [roomId]。
/// `unlocks.rooms` 由 T1.8c 维护（完成首个官方挑战后 push 进 ID）；
/// 当前 T1.8c 未实施，演示前可手工在 Console 改字段验证两态。
///
/// 路由层面这里**总是可进入**——未解锁态在屏内统一渲染锁定提示，
/// 不在路由守卫做硬拦截，避免后续解锁后用户卡住的状态污染。
class ZenGardenScreen extends StatelessWidget {
  const ZenGardenScreen({super.key});

  static const roomId = 'zen_garden';

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/gallery'),
        ),
        title: const Text('禅意花园'),
      ),
      body: uid == null
          ? const Center(child: Text('请先登录'))
          : StreamBuilder<UserProfile?>(
              stream: UserRepository.instance.watchProfile(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: BrushLoading());
                }
                final unlocked =
                    snap.data?.unlocks.rooms.contains(roomId) ?? false;
                return unlocked ? const _UnlockedView() : const _LockedView();
              },
            ),
    );
  }
}

/// 已解锁视图：静态美术 + 一行禅意提示。
/// `fronted-design.md` §9 设想沙纹 / 石景 / 飘落折纸叶动效，本版仅静态。
class _UnlockedView extends StatelessWidget {
  const _UnlockedView();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [skin.surfaceCard, skin.paperShade],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: skin.goldLeaf, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_outlined, size: 56, color: skin.goldLeaf),
              const SizedBox(height: 12),
              Text(
                '禅意花园',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: skin.inkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '沙纹 · 石景 · 落纸',
                style: TextStyle(fontSize: 12, color: skin.inkSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '一砂一世界。\n落纸不语，自有声。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.8, color: skin.inkPrimary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: skin.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: skin.paperShade),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: skin.inkSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '完整动效（沙纹光影、飘落折纸叶）将在后续补齐。',
                  style: TextStyle(fontSize: 12, color: skin.inkSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: skin.surfaceCard,
                border: Border.all(color: skin.inkFaint),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: OrigamiIcon(OrigamiGlyph.lock,
                  size: 44, color: skin.inkSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              '禅意花园未解锁',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: skin.inkPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成首个官方挑战即可解锁',
              style: TextStyle(fontSize: 13, color: skin.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
