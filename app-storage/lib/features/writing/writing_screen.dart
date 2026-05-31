import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/challenge.dart';
import '../../data/repositories/challenge_repository.dart';

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

/// 官方挑战入口卡片：展示当前活跃挑战的三词，点击领取进入编辑器。
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
          child: InkWell(
            onTap: () => context.go('/writing/editor', extra: {
              'mode': 'official',
              'challengeId': challenge.id,
              'words': challenge.words,
            }),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/writing/editor', extra: {
                      'mode': 'official',
                      'challengeId': challenge.id,
                      'words': challenge.words,
                    }),
                    icon: const Icon(Icons.edit),
                    label: const Text('领取挑战，开始写作'),
                  ),
                ],
              ),
            ),
          ),
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
