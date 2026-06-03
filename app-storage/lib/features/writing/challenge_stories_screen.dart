import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/challenge.dart';
import '../../data/models/story.dart';
import '../../data/repositories/challenge_repository.dart';
import '../../data/repositories/story_repository.dart';
import '../../theme/skin_controller.dart';
import '../../widgets/brush_loading.dart';
import '../../widgets/origami_icon.dart';
import '../../widgets/origami_icons.dart';

/// 本期挑战故事列表：用 `streamByChallenge` 聚合所有 `mode=official` 且
/// `challengeId=入参` 的 story（验证 T2.2 验收条款）。
class ChallengeStoriesScreen extends StatelessWidget {
  const ChallengeStoriesScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/writing'),
        ),
        title: const Text('本期挑战故事'),
      ),
      body: FutureBuilder<Challenge?>(
        future: ChallengeRepository.instance.getById(challengeId),
        builder: (context, challengeSnap) {
          final challenge = challengeSnap.data;
          return Column(
            children: [
              if (challenge != null) _ChallengeHeader(challenge: challenge),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<Story>>(
                  stream: StoryRepository.instance
                      .streamByChallenge(challengeId, limit: 100),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: BrushLoading());
                    }
                    final stories = snap.data ?? const [];
                    if (stories.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OrigamiIcon(OrigamiGlyph.emptyPaper,
                                  size: 48, color: context.skin.inkFaint),
                              const SizedBox(height: 10),
                              Text(
                                '本期还没有故事，做第一个交卷的人',
                                style: TextStyle(color: context.skin.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: stories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _StoryRow(story: stories[i]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChallengeHeader extends StatelessWidget {
  const _ChallengeHeader({required this.challenge});
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: context.skin.paperBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(challenge.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: challenge.words
                .map((w) => Chip(
                      label: Text(w,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Card(
      child: ListTile(
        title: Text(
          story.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              story.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: skin.inkSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  story.authorName,
                  style: TextStyle(fontSize: 12, color: skin.inkSecondary),
                ),
                const Spacer(),
                OrigamiIcon(OrigamiGlyph.heart,
                    size: 14, fill: true, color: skin.accentVermilion),
                const SizedBox(width: 4),
                Text('${story.likeCount}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.comment_outlined, size: 14, color: skin.inkSecondary),
                const SizedBox(width: 4),
                Text('${story.commentCount}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
