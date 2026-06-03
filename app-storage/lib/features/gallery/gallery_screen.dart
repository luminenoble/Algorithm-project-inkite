import 'package:flutter/material.dart';

import '../../data/models/origami.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/origami_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';
import '../common/magic_ink.dart';
import 'widgets/origami_card.dart';
import 'widgets/room_entry_card.dart';

/// 展览厅 Tab 主屏。
///
/// 顶部主题房间入口（T4.3），下方折纸藏品网格（T4.1）。
/// T4.4 在此挂金箔点缀。
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    return Scaffold(
      appBar: AppBar(title: const Text('展览厅')),
      body: uid == null
          ? const Center(child: Text('请先登录'))
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: MagicInkBanner()),
                const SliverToBoxAdapter(child: RoomEntryCard()),
                const SliverToBoxAdapter(child: _SectionLabel(text: '折纸藏品')),
                _OrigamiSliver(uid: uid),
              ],
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
  const _OrigamiSliver({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.instance.watchProfile(uid),
      builder: (context, profileSnap) {
        final goldEdge = profileSnap.data?.unlocks.magicInk ?? false;
        return _OrigamiInner(uid: uid, goldEdge: goldEdge);
      },
    );
  }
}

class _OrigamiInner extends StatelessWidget {
  const _OrigamiInner({required this.uid, required this.goldEdge});
  final String uid;
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
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrigamiIcon(OrigamiGlyph.emptyPaper, size: 64, color: skin.inkFaint),
            const SizedBox(height: 16),
            Text(
              '还没有折纸藏品',
              style: TextStyle(
                fontSize: 16,
                color: skin.inkPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '完成官方挑战，解锁第一件折纸',
              style: TextStyle(fontSize: 13, color: skin.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
