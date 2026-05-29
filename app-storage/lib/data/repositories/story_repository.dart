import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/story.dart';

/// `stories` 集合的 CRUD / 监听入口。
///
/// 客户端绝不写 `likeCount` / `commentCount` / `hotScore`——这三个字段由
/// T1.7 触发器维护，T1.4 规则强制拦截前端写入。
class StoryRepository {
  StoryRepository._();
  static final StoryRepository instance = StoryRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('stories');

  // ---------------------------------------------------------------
  // 写
  // ---------------------------------------------------------------

  /// 创建一条 story；返回新文档 ID。
  Future<String> create(Story draft) async {
    final ref = await _col.add(draft.toCreateMap());
    return ref.id;
  }

  /// 局部更新；只允许列出的字段，避免误写 CF-only 计数。
  Future<void> update(
    String storyId, {
    String? title,
    String? body,
    StoryVisibility? visibility,
    bool? publishedToSquare,
  }) {
    final patch = <String, dynamic>{
      'title': ?title,
      'body': ?body,
      'visibility': ?visibility?.name,
      'publishedToSquare': ?publishedToSquare,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _col.doc(storyId).update(patch);
  }

  Future<void> delete(String storyId) => _col.doc(storyId).delete();

  // ---------------------------------------------------------------
  // 读
  // ---------------------------------------------------------------

  Future<Story?> getById(String storyId) async {
    final snap = await _col.doc(storyId).get();
    if (!snap.exists) return null;
    return Story.fromFirestore(snap);
  }

  Stream<Story?> watchById(String storyId) {
    return _col.doc(storyId).snapshots().map(
          (snap) => snap.exists ? Story.fromFirestore(snap) : null,
        );
  }

  /// 广场动态 / 排行榜流。
  /// - [SquareSort.hotScore]：依赖 T1.4 已声明的 `visibility ASC + hotScore DESC` 复合索引
  /// - [SquareSort.newest]：`visibility` 单字段过滤 + `createdAt` 倒序（无需额外索引）
  Stream<List<Story>> streamSquareFeed({
    SquareSort sort = SquareSort.hotScore,
    int limit = 50,
  }) {
    final base = _col.where('visibility', isEqualTo: StoryVisibility.public.name);
    final Query<Map<String, dynamic>> q = switch (sort) {
      SquareSort.hotScore =>
        base.orderBy('hotScore', descending: true).limit(limit),
      SquareSort.newest =>
        base.orderBy('createdAt', descending: true).limit(limit),
    };
    return q.snapshots().map(
          (qs) => qs.docs.map(Story.fromFirestore).toList(growable: false),
        );
  }

  /// 「我的故事」列表。需要 `authorId ASC + createdAt DESC` 复合索引（T1.4 已声明）。
  Stream<List<Story>> streamMyStories(String uid, {int limit = 50}) {
    return _col
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) =>
            qs.docs.map(Story.fromFirestore).toList(growable: false));
  }

  /// 「按官方挑战聚合」列表。需要 `mode + challengeId + createdAt` 复合索引（T1.4 已声明）。
  Stream<List<Story>> streamByChallenge(
    String challengeId, {
    int limit = 50,
  }) {
    return _col
        .where('mode', isEqualTo: StoryMode.official.name)
        .where('challengeId', isEqualTo: challengeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) =>
            qs.docs.map(Story.fromFirestore).toList(growable: false));
  }
}
