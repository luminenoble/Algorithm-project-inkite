import 'package:flutter/material.dart';

import '../data/models/story.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/story_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/unlock_state.dart';
import '../services/auth_service.dart';

/// 把当前用户的「已发布故事词集 + 解锁旗标」合成一个 [UnlockResolver] 下发。
///
/// 合并两条流：`StoryRepository.streamMyStories`（词语派生）+
/// `UserRepository.watchProfile`（旧 CF 旗标兼容）。调用方零成本接入解锁判定，
/// 切换/发布后自动重建（`docs/fronted/unlock-halls.plan.md`）。
class UnlockBuilder extends StatelessWidget {
  const UnlockBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, UnlockResolver) builder;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUid;
    if (uid == null) {
      return builder(
        context,
        UnlockResolver(
          publishedSubwords: const {},
          magicInkFlag: false,
          unlockedRooms: const [],
        ),
      );
    }
    return StreamBuilder<List<Story>>(
      stream: StoryRepository.instance.streamMyStories(uid),
      builder: (context, storySnap) {
        return StreamBuilder<UserProfile?>(
          stream: UserRepository.instance.watchProfile(uid),
          builder: (context, profileSnap) {
            final resolver = UnlockResolver.from(
              myStories: storySnap.data ?? const [],
              profile: profileSnap.data,
            );
            return builder(context, resolver);
          },
        );
      },
    );
  }
}
