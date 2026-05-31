import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/challenge.dart';
import '../../data/models/story.dart';
import '../../data/repositories/challenge_repository.dart';
import '../../data/repositories/story_repository.dart';

/// 写作 Tab 落地页：官方挑战入口 + 自由创作入口。
class WritingScreen extends StatelessWidget {
  const WritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写作')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _OfficialChallengeCard(),
          const SizedBox(height: 16),
          _FreeModeCard(),
        ],
      ),
    );
  }
}

/// 官方挑战入口卡片：展示当前活跃挑战、倒计时、本期已提交数，
/// 点击领取进入编辑器；附"查看本期故事"二级入口。
class _OfficialChallengeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Challenge?>(
      stream: ChallengeRepository.instance.watchActive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final challenge = snapshot.data;
        if (challenge == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    '暂无活跃挑战',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '官方挑战会定期发布，敬请期待',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFC2410C)),
                    const SizedBox(width: 8),
                    Text(
                      '官方挑战',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (challenge.endAt != null)
                      _CountdownChip(endAt: challenge.endAt!),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: challenge.words
                      .map((w) => Chip(
                            label: Text(w),
                            backgroundColor: const Color(0xFFF5F1E8),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                _SubmissionStats(challengeId: challenge.id),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/writing/editor', extra: {
                        'mode': 'official',
                        'challengeId': challenge.id,
                        'words': challenge.words,
                      }),
                      icon: const Icon(Icons.edit),
                      label: const Text('领取挑战，开始写作'),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go(
                        '/writing/challenge/${challenge.id}',
                      ),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('查看本期故事'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 倒计时小徽章：根据 `endAt` 计算 "剩 X 天 / X 小时 / 已结束"。
class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.endAt});
  final DateTime endAt;

  String _label() {
    final diff = endAt.difference(DateTime.now());
    if (diff.isNegative) return '已结束';
    if (diff.inDays >= 1) return '剩 ${diff.inDays} 天';
    if (diff.inHours >= 1) return '剩 ${diff.inHours} 小时';
    return '剩 ${diff.inMinutes} 分';
  }

  @override
  Widget build(BuildContext context) {
    final ended = endAt.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ended ? const Color(0xFFC9C0B2) : const Color(0xFFC2410C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// 本期挑战已提交数（用 `streamByChallenge` 实时聚合）。
class _SubmissionStats extends StatelessWidget {
  const _SubmissionStats({required this.challengeId});
  final String challengeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Story>>(
      stream: StoryRepository.instance
          .streamByChallenge(challengeId, limit: 100),
      builder: (context, snap) {
        final count = snap.data?.length ?? 0;
        return Row(
          children: [
            const Icon(Icons.groups_outlined,
                size: 16, color: Color(0xFF6B6258)),
            const SizedBox(width: 6),
            Text(
              '本期已有 $count 篇故事',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B6258),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 自由创作入口卡片。
class _FreeModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/writing/editor', extra: {
          'mode': 'free',
        }),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.brush, color: Color(0xFF6B6258)),
                  const SizedBox(width: 8),
                  Text(
                    '自由创作',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '不限题材，随心书写你的故事',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6258),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/writing/editor', extra: {
                  'mode': 'free',
                }),
                icon: const Icon(Icons.edit_note),
                label: const Text('开始写作'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
