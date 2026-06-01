import 'package:flutter/material.dart';

import '../../data/models/origami.dart';
import '../../data/repositories/origami_repository.dart';
import '../../services/auth_service.dart';
import 'widgets/origami_card.dart';

/// 展览厅 Tab 主屏。
///
/// 主要展示当前用户的折纸藏品网格（`OrigamiRepository.streamMine`）。
/// T4.3 / T4.4 会在这里追加主题房间入口与魔法墨水视觉。
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(title: const Text('展览厅')),
      body: uid == null
          ? const Center(child: Text('请先登录'))
          : _OrigamiGrid(uid: uid),
    );
  }
}

class _OrigamiGrid extends StatelessWidget {
  const _OrigamiGrid({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Origami>>(
      stream: OrigamiRepository.instance.streamMine(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '加载失败：${snap.error}',
                style: const TextStyle(color: Color(0xFF9A2D1F)),
              ),
            ),
          );
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) return const _EmptyState();
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => OrigamiCard(origami: list[i]),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F0),
                border: Border.all(color: const Color(0xFFC9C0B2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                size: 32,
                color: Color(0xFF6B6258),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有折纸藏品',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF2B2622),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '完成官方挑战，解锁第一件折纸',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B6258)),
            ),
          ],
        ),
      ),
    );
  }
}
