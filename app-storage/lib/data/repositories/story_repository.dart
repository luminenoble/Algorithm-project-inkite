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
  ///
  /// [storybookId] / [chapterName] 用于把故事移动到别的书/章节（T6，§3.2）；
  /// 不传则保持原归属。移动后调用方需 `StorybookRepository.touch` 刷新两端
  /// `updatedAt`（让「修改时间排序」准确）。
  Future<void> update(
    String storyId, {
    String? title,
    String? body,
    StoryVisibility? visibility,
    bool? publishedToSquare,
    String? storybookId,
    String? chapterName,
  }) {
    final patch = <String, dynamic>{
      'title': ?title,
      'body': ?body,
      'visibility': ?visibility?.name,
      'publishedToSquare': ?publishedToSquare,
      'storybookId': ?storybookId,
      'chapterName': ?chapterName,
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
  /// 两条都需要复合索引（`where + orderBy` 跨字段组合 Firestore 强制要求）：
  /// - [SquareSort.hotScore]：`visibility ASC + hotScore DESC`
  /// - [SquareSort.newest]：`visibility ASC + createdAt DESC`
  /// 两条索引均在 `firestore.indexes.json` 声明并已部署。
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

  /// 「故事书内按章节聚合」列表（T6，§3.2）。需要
  /// `storybookId ASC + chapterName ASC + createdAt ASC` 复合索引
  /// （`firestore.indexes.json` 已声明）。拉到该书全部 story，
  /// 由调用方在客户端按 `chapterName` 分组。
  Stream<List<Story>> streamByStorybook(
    String storybookId, {
    int limit = 200,
  }) {
    return _col
        .where('storybookId', isEqualTo: storybookId)
        .orderBy('chapterName')
        .orderBy('createdAt')
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
