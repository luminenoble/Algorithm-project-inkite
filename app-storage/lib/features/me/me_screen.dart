import 'package:flutter/material.dart';

import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_service.dart';

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
                    return const Center(child: CircularProgressIndicator());
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
