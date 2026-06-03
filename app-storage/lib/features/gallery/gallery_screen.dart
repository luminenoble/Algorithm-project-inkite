import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/origami.dart';
import '../../data/repositories/origami_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/ink_skin.dart';
import '../../theme/motion.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import '../../widgets/paper_bird_overlay.dart';
import '../../widgets/unlock_builder.dart';
import '../common/magic_ink.dart';
import 'hall.dart';
import 'widgets/hall_switcher.dart';
import 'widgets/origami_card.dart';

/// 展览厅 Tab 主屏。
///
/// 顶部展馆切换器（默认馆显示全部，主题馆按 style 过滤、词语解锁），
/// 下方折纸藏品网格（T4.1）。魔法墨水解锁时挂金箔点缀（T4.4）。
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  /// 会话级：上次放鸟时刻，避免来回切 Tab 反复触发（§4 频繁降级）。
  static DateTime? _lastBirdAt;
  bool _entered = false;

  /// 当前所选展馆（默认馆）。
  GalleryHall _hall = galleryHalls.first;

  @override
  void initState() {
    super.initState();
    // 翻书折叠落定后再放鸟（§3.2 特例）：post-frame 触发。
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEnter());
  }

  void _onEnter() {
    if (!mounted) return;
    final now = DateTime.now();
    final last = _lastBirdAt;
    final shouldFly =
        last == null || now.difference(last) > const Duration(seconds: 30);
    if (shouldFly) {
      _lastBirdAt = now;
      final media = MediaQuery.of(context);
      // 纸鸟从屏幕左下起飞，沿弧线飞向右上离场（§4）。
      launchPaperBird(
        context,
        from: Offset(40, media.size.height - 140),
        to: Offset(media.size.width - 48, media.padding.top + 64),
      );
    }
    setState(() => _entered = true); // 触发画廊内容淡入落定
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    // 鸟飞过后画廊内容轻微淡入落定（§4.4 的轻量版）。
    final visible = _entered || !context.motion.useRichMotion;
    return Scaffold(
      appBar: AppBar(title: const Text('展览厅')),
      body: uid == null
          ? const Center(child: Text('请先登录'))
          : AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.durFold,
              curve: Motion.curveFold,
              child: UnlockBuilder(
                builder: (context, resolver) {
                  // 若所选主题馆未解锁（极少见：发布被撤回），回落默认馆。
                  if (!_hall.unlockedBy(resolver)) {
                    _hall = galleryHalls.first;
                  }
                  final goldEdge = resolver.inkUnlocked(InkSkin.magicFlow);
                  return CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: MagicInkBanner()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: HallSwitcher(
                            resolver: resolver,
                            selectedId: _hall.id,
                            onSelect: (h) => setState(() => _hall = h),
                          ),
                        ),
                      ),
                      if (_hall.id == 'zen')
                        const SliverToBoxAdapter(child: _ZenHallBanner()),
                      SliverToBoxAdapter(
                        child: _SectionLabel(text: '${_hall.name} · 折纸藏品'),
                      ),
                      _OrigamiSliver(uid: uid, hall: _hall, goldEdge: goldEdge),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// 禅意阁选中时的沉浸入口 banner。
class _ZenHallBanner extends StatelessWidget {
  const _ZenHallBanner();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: skin.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/gallery/room/zen-garden'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: skin.goldLeaf, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(Icons.spa_outlined, size: 26, color: skin.goldLeaf),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '进入沉浸花园',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: skin.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '沙纹 · 石景 · 落纸',
                        style:
                            TextStyle(fontSize: 12, color: skin.inkSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: skin.inkPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: skin.inkPrimary,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _OrigamiSliver extends StatelessWidget {
  const _OrigamiSliver({
    required this.uid,
    required this.hall,
    required this.goldEdge,
  });
  final String uid;
  final GalleryHall hall;
  final bool goldEdge;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Origami>>(
      stream: OrigamiRepository.instance.streamMine(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: BrushLoading()),
          );
        }
        if (snap.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '加载失败：${snap.error}',
                  style: TextStyle(color: context.skin.accentSeal),
                ),
              ),
            ),
          );
        }
        final all = snap.data ?? const <Origami>[];
        final list = all.where(hall.accepts).toList(growable: false);
        if (list.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(hall: hall),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => OrigamiCard(
              origami: list[i],
              goldEdge: goldEdge,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hall});
  final GalleryHall hall;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isDefault = hall.isDefault;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(OrigamiGlyph.emptyPaper, size: 64, color: skin.inkFaint),
            const SizedBox(height: 16),
            Text(
              isDefault ? '还没有折纸藏品' : '${hall.name}暂无藏品',
              style: TextStyle(
                fontSize: 16,
                color: skin.inkPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isDefault ? '完成官方挑战，解锁第一件折纸' : '完成该主题的官方挑战即可收藏',
              style: TextStyle(fontSize: 13, color: skin.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
