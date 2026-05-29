import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/story_comment.dart';

/// `stories/{storyId}/comments` 子集合入口。
///
/// `commentCount` 字段在父 story 上由 T1.7 触发器维护，Repository 不动它。
class CommentRepository {
  CommentRepository._();
  static final CommentRepository instance = CommentRepository._();

  CollectionReference<Map<String, dynamic>> _col(String storyId) =>
      FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('comments');

  /// 新增评论，返回 commentId。
  /// `comment.authorId` 必须等于当前 uid，否则 T1.4 规则会拒。
  Future<String> add(String storyId, StoryComment comment) async {
    final ref = await _col(storyId).add(comment.toCreateMap());
    return ref.id;
  }

  Future<void> delete(String storyId, String commentId) {
    return _col(storyId).doc(commentId).delete();
  }

  /// 按时间倒序展示（最新在前）；MVP 不做楼中楼 / 分页。
  Stream<List<StoryComment>> watchComments(
    String storyId, {
    int limit = 100,
  }) {
    return _col(storyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) =>
            qs.docs.map(StoryComment.fromFirestore).toList(growable: false));
  }
}
