import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/ink_skin.dart';
import '../../theme/motion.dart';
import '../../theme/paper_skin.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';

/// 我的 Tab：展示当前 `users/{uid}` 档案 + 登出。
/// 角色查询（模块 G）嵌入位置由 P4 决定，本页不做。
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final uid = auth.currentUid;
    final email = auth.currentUser?.email;
    final isAnonymous = auth.currentUser?.isAnonymous ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text('未登录'))
            : StreamBuilder<UserProfile?>(
                stream: UserRepository.instance.watchProfile(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: BrushLoading());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('读取档案失败：${snap.error}'));
                  }
                  final profile = snap.data;
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _ProfileHeader(
                        displayName: profile?.displayName ?? '(无昵称)',
                        subtitle: isAnonymous ? '匿名用户' : (email ?? uid),
                      ),
                      const SizedBox(height: 24),
                      if (profile != null) ...[
                        _StatsCard(stats: profile.stats),
                        const SizedBox(height: 12),
                        _UnlocksCard(unlocks: profile.unlocks),
                        const SizedBox(height: 12),
                        _SkinSection(
                            magicInkUnlocked: profile.unlocks.magicInk),
                        const SizedBox(height: 12),
                        const _MotionSection(),
                      ] else
                        const Card(
                          child: ListTile(
                            title: Text('档案尚未初始化'),
                            subtitle: Text('请重新登录以触发初始化'),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton.tonal(
                        onPressed: () => AuthService.instance.signOut(),
                        child: const Text('登出'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'uid: $uid',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.subtitle});

  final String displayName;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          child: Text(
            displayName.isNotEmpty ? displayName.characters.first : '?',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatBlock(label: '故事', value: stats.storiesCount),
            _StatBlock(label: '收到点赞', value: stats.likesReceived),
            _StatBlock(label: '参与度', value: stats.engagementScore),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _UnlocksCard extends StatelessWidget {
  const _UnlocksCard({required this.unlocks});

  final UserUnlocks unlocks;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('解锁状态', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  unlocks.magicInk ? Icons.check_circle : Icons.lock_outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(unlocks.magicInk ? '魔法墨水已解锁' : '魔法墨水未解锁'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              unlocks.rooms.isEmpty
                  ? '主题房间：暂无'
                  : '主题房间：${unlocks.rooms.join(", ")}',
            ),
          ],
        ),
      ),
    );
  }
}

/// 皮肤切换区（`docs/fronted-design.md` §8.2）。
///
/// 纸张 / 墨水皮肤各一排横向缩略图选择器；切换即时换装（走 [SkinController]）。
/// 未解锁墨水（魔法墨水）显示锁形，点按提示解锁条件——皮肤系统**只读**
/// `users.unlocks`，绝不写库（§8.3）。
class _SkinSection extends StatelessWidget {
  const _SkinSection({required this.magicInkUnlocked});

  final bool magicInkUnlocked;

  @override
  Widget build(BuildContext context) {
    final controller = SkinScope.of(context);
    final skin = context.skin; // 依赖 SkinScope：切皮肤即时重建高亮
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('皮肤', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('纸张', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in PaperSkin.presets)
                    _PaperSwatch(
                      paper: p,
                      selected: p.id == skin.paper.id,
                      onTap: () => controller.setPaper(p),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('墨水', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ink in InkSkin.presets)
                    _InkSwatch(
                      ink: ink,
                      selected: ink.id == skin.ink.id,
                      locked: ink.requiresUnlock && !magicInkUnlocked,
                      onTap: () {
                        if (ink.requiresUnlock && !magicInkUnlocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('魔法墨水：互动分达标后自动解锁')),
                          );
                          return;
                        }
                        controller.setInk(ink);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final PaperSkin paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SwatchFrame(
      selected: selected,
      label: paper.displayName,
      onTap: onTap,
      preview: Column(
        children: [
          Expanded(child: ColoredBox(color: paper.paperHighlight)),
          Expanded(child: ColoredBox(color: paper.paperBase)),
          Expanded(child: ColoredBox(color: paper.paperShade)),
        ],
      ),
    );
  }
}

class _InkSwatch extends StatelessWidget {
  const _InkSwatch({
    required this.ink,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final InkSkin ink;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SwatchFrame(
      selected: selected,
      locked: locked,
      label: ink.displayName,
      onTap: onTap,
      preview: ColoredBox(
        color: ink.inkPrimary,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ink.accentVermilion,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 16, height: 4, color: ink.inkSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 缩略图外框：56×56 预览 + 名称，选中描朱砂，锁定显锁形。
class _SwatchFrame extends StatelessWidget {
  const _SwatchFrame({
    required this.preview,
    required this.selected,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final Widget preview;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final accent = skin.accentVermilion;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? accent : skin.inkFaint,
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  if (locked)
                    ColoredBox(
                      color: skin.paperBase.withValues(alpha: 0.55),
                      child: Center(
                        child: OrigamiIcon(OrigamiGlyph.lock,
                            size: 22, color: skin.goldLeaf),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? accent : skin.inkSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 动效级别设置（§7.1）：全动效 / 淡入淡出 / 关闭。
class _MotionSection extends StatelessWidget {
  const _MotionSection();

  @override
  Widget build(BuildContext context) {
    final controller = SkinScope.of(context);
    final motion = context.motion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('动效', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('翻书折叠与纸鸟动画的强弱',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SegmentedButton<MotionLevel>(
              segments: [
                for (final m in MotionLevel.values)
                  ButtonSegment(value: m, label: Text(m.displayName)),
              ],
              selected: {motion},
              onSelectionChanged: (s) => controller.setMotion(s.first),
            ),
          ],
        ),
      ),
    );
  }
}
