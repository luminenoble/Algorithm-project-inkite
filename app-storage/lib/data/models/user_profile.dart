import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}` 文档的强类型映射。
///
/// 字段对齐 `docs/schema-design/design.md §1`。
/// `stats.*` 与 `unlocks.*` 由 Cloud Functions 维护，客户端只读。
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.createdAt,
    required this.stats,
    required this.unlocks,
  });

  final String uid;
  final String displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final UserStats stats;
  final UserUnlocks unlocks;

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    final statsRaw = (data['stats'] as Map<String, dynamic>?) ?? const {};
    final unlocksRaw = (data['unlocks'] as Map<String, dynamic>?) ?? const {};
    return UserProfile(
      uid: snap.id,
      displayName: (data['displayName'] as String?) ?? '',
      photoURL: data['photoURL'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      stats: UserStats.fromMap(statsRaw),
      unlocks: UserUnlocks.fromMap(unlocksRaw),
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
      },
      'unlocks': {
        'magicInk': false,
        'rooms': <String>[],
      },
    };
  }
}

class UserStats {
  const UserStats({
    required this.storiesCount,
    required this.likesReceived,
    required this.engagementScore,
  });

  final int storiesCount;
  final int likesReceived;
  final int engagementScore;

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        storiesCount: (m['storiesCount'] as num?)?.toInt() ?? 0,
        likesReceived: (m['likesReceived'] as num?)?.toInt() ?? 0,
        engagementScore: (m['engagementScore'] as num?)?.toInt() ?? 0,
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
