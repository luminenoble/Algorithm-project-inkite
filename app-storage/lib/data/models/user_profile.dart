import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}` 文档的强类型映射。
///
/// 字段对齐 `docs/schema-design/design.md §1`。
/// `stats.*` / `unlocks.*` / `aiUsage.*` 由 Cloud Functions 维护，客户端只读。
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.createdAt,
    required this.stats,
    required this.unlocks,
    required this.aiUsage,
  });

  final String uid;
  final String displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final UserStats stats;
  final UserUnlocks unlocks;
  final UserAiUsage aiUsage;

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    final statsRaw = (data['stats'] as Map<String, dynamic>?) ?? const {};
    final unlocksRaw = (data['unlocks'] as Map<String, dynamic>?) ?? const {};
    final aiUsageRaw =
        (data['aiUsage'] as Map<String, dynamic>?) ?? const {};
    return UserProfile(
      uid: snap.id,
      displayName: (data['displayName'] as String?) ?? '',
      photoURL: data['photoURL'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      stats: UserStats.fromMap(statsRaw),
      unlocks: UserUnlocks.fromMap(unlocksRaw),
      aiUsage: UserAiUsage.fromMap(aiUsageRaw),
    );
  }

  /// 用于"首次登录写初始档案"。`createdAt` 用 `serverTimestamp()`，
  /// 由 Firestore 服务端填值——这里返回的 Map 里相应字段是 sentinel。
  static Map<String, dynamic> initialDoc({
    required String displayName,
  }) {
    return {
      'displayName': displayName,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'stats': {
        'storiesCount': 0,
        'likesReceived': 0,
        'engagementScore': 0,
        'officialChallengesCount': 0,
      },
      'unlocks': {
        'magicInk': false,
        'rooms': <String>[],
      },
      'aiUsage': {
        'weekStartAt': null,
        'count': 0,
        'bonusLikes': false,
        'bonusChallenges': false,
      },
    };
  }
}

class UserStats {
  const UserStats({
    required this.storiesCount,
    required this.likesReceived,
    required this.engagementScore,
    required this.officialChallengesCount,
  });

  final int storiesCount;
  final int likesReceived;
  final int engagementScore;
  final int officialChallengesCount;

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        storiesCount: (m['storiesCount'] as num?)?.toInt() ?? 0,
        likesReceived: (m['likesReceived'] as num?)?.toInt() ?? 0,
        engagementScore: (m['engagementScore'] as num?)?.toInt() ?? 0,
        officialChallengesCount:
            (m['officialChallengesCount'] as num?)?.toInt() ?? 0,
      );
}

/// F2：AI 折纸配额状态。CF maintained 通过 generateAiOrigami 调用过程更新 count、
/// 通过 T1.8c 触发器在阈值跨越时翻 bonus flag。
class UserAiUsage {
  const UserAiUsage({
    required this.weekStartAt,
    required this.count,
    required this.bonusLikes,
    required this.bonusChallenges,
  });

  /// 本周窗口起点（首次调用时间）。null = 从未调用过。
  final DateTime? weekStartAt;

  /// 本周已用次数（window 过期时下次调用会自动重置为 1）。
  final int count;

  /// likesReceived 已跨过 20 → +1 quota，单向翻 true。
  final bool bonusLikes;

  /// officialChallengesCount 已跨过 5 → +1 quota，单向翻 true。
  final bool bonusChallenges;

  factory UserAiUsage.fromMap(Map<String, dynamic> m) => UserAiUsage(
        weekStartAt: (m['weekStartAt'] as Timestamp?)?.toDate(),
        count: (m['count'] as num?)?.toInt() ?? 0,
        bonusLikes: (m['bonusLikes'] as bool?) ?? false,
        bonusChallenges: (m['bonusChallenges'] as bool?) ?? false,
      );
}

class UserUnlocks {
  const UserUnlocks({
    required this.magicInk,
    required this.rooms,
  });

  final bool magicInk;
  final List<String> rooms;

  factory UserUnlocks.fromMap(Map<String, dynamic> m) => UserUnlocks(
        magicInk: (m['magicInk'] as bool?) ?? false,
        rooms: ((m['rooms'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );
}
