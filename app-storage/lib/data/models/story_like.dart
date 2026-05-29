import 'package:cloud_firestore/cloud_firestore.dart';

/// `stories/{storyId}/likes/{uid}` 文档的强类型映射。
///
/// 文档 ID 即点赞者 uid（schema 幂等性保证）；字段极简，仅 `createdAt`。
class StoryLike {
  const StoryLike({required this.uid, required this.createdAt});

  final String uid;
  final DateTime? createdAt;

  factory StoryLike.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    return StoryLike(
      uid: snap.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
