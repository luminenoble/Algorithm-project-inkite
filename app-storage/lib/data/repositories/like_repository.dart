import 'package:cloud_firestore/cloud_firestore.dart';

/// `stories/{storyId}/likes/{uid}` 子集合入口。
///
/// 文档 ID 强制等于 uid，幂等性来自 schema + T1.4 规则。
/// 父 story 上的 `likeCount` 由 T1.7 触发器维护，本仓库不动。
class LikeRepository {
  LikeRepository._();
  static final LikeRepository instance = LikeRepository._();

  DocumentReference<Map<String, dynamic>> _ref(String storyId, String uid) =>
      FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('likes')
          .doc(uid);

  Future<bool> hasLiked(String storyId, String uid) async {
    final snap = await _ref(storyId, uid).get();
    return snap.exists;
  }

  Stream<bool> watchHasLiked(String storyId, String uid) {
    return _ref(storyId, uid).snapshots().map((s) => s.exists);
  }

  /// 切换点赞状态：存在则删，不存在则建。
  Future<void> toggle(String storyId, String uid) async {
    final ref = _ref(storyId, uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
