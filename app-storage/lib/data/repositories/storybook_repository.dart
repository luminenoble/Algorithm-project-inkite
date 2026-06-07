import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/storybook.dart';

/// `storybooks` 集合的 CRUD / 监听入口（`docs/next-design-detailed.md` §3.1）。
///
/// 客户端绝不写 `coverUrl`——它由 Cloud Function `uploadStorybookCover` 写入，
/// 安全规则强制拦截前端写入。封面上传走 `StorybookService.uploadCover`（调 CF），
/// 不在本 Repository 直传，守 `CLAUDE.md` §7「客户端不直连 Storage」。
class StorybookRepository {
  StorybookRepository._();
  static final StorybookRepository instance = StorybookRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('storybooks');

  CollectionReference<Map<String, dynamic>> get _stories =>
      FirebaseFirestore.instance.collection('stories');

  // ---------------------------------------------------------------
  // 读
  // ---------------------------------------------------------------

  /// 故事书总览：置顶优先 + 指定时间排序。
  /// 需复合索引（`firestore.indexes.json` 已声明，随 T1.10a 部署）：
  /// - [StorybookSort.updatedAt]：`ownerId ASC + pinned DESC + updatedAt DESC`
  /// - [StorybookSort.createdAt]：`ownerId ASC + pinned DESC + createdAt DESC`
  Stream<List<Storybook>> streamMine(
    String uid, {
    StorybookSort sort = StorybookSort.updatedAt,
  }) {
    final field =
        sort == StorybookSort.createdAt ? 'createdAt' : 'updatedAt';
    return _col
        .where('ownerId', isEqualTo: uid)
        .orderBy('pinned', descending: true)
        .orderBy(field, descending: true)
        .snapshots()
        .map((qs) =>
            qs.docs.map(Storybook.fromFirestore).toList(growable: false));
  }

  Future<Storybook?> getById(String storybookId) async {
    final snap = await _col.doc(storybookId).get();
    if (!snap.exists) return null;
    return Storybook.fromFirestore(snap);
  }

  Stream<Storybook?> watchById(String storybookId) {
    return _col.doc(storybookId).snapshots().map(
          (snap) => snap.exists ? Storybook.fromFirestore(snap) : null,
        );
  }

  // ---------------------------------------------------------------
  // 写
  // ---------------------------------------------------------------

  /// 惰性拿/建默认书：返回该用户的 `isDefault` 书；无则用确定性 ID
  /// `default_{uid}` 创建（幂等——同一 uid 多次调只得一本默认书）。
  Future<Storybook> getOrCreateDefault(String uid) async {
    final ref = _col.doc(defaultStorybookId(uid));
    final snap = await ref.get();
    if (snap.exists) return Storybook.fromFirestore(snap);

    final draft = Storybook(
      id: ref.id,
      ownerId: uid,
      title: kDefaultStorybookTitle,
      coverUrl: null,
      coverAssetId: null,
      chapterOrder: const [kDefaultChapter],
      isDefault: true,
      pinned: false,
      createdAt: null,
      updatedAt: null,
    );
    // 确定性 ID 用 set（而非 add）保证幂等：并发首登也只会写同一文档。
    await ref.set(draft.toCreateMap());
    final created = await ref.get();
    return Storybook.fromFirestore(created);
  }

  /// 创建一本新故事书；返回新 storybookId。
  Future<String> create(Storybook draft) async {
    final ref = await _col.add(draft.toCreateMap());
    return ref.id;
  }

  /// 改名（默认书禁用——Repository 二次防御 + 安全规则双重拦截）。
  Future<void> rename(String storybookId, String title) async {
    final book = await getById(storybookId);
    if (book == null) return;
    if (book.isDefault) {
      throw StateError('默认故事书不可改名');
    }
    await _col.doc(storybookId).update({
      'title': title,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPinned(String storybookId, bool pinned) {
    return _col.doc(storybookId).update({
      'pinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 选内置预设封面（纯前端写 `coverAssetId`）。
  /// 注：`coverUrl` 优先，已上传过自定义封面时此设置不可见（§1.2）。
  Future<void> setCoverAsset(String storybookId, String coverAssetId) {
    return _col.doc(storybookId).update({
      'coverAssetId': coverAssetId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setChapterOrder(String storybookId, List<String> order) {
    return _col.doc(storybookId).update({
      'chapterOrder': order,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 仅刷新 `updatedAt`（story 增删 / 移动后调，让「修改时间排序」准确）。
  Future<void> touch(String storybookId) {
    return _col.doc(storybookId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 删除一本故事书。
  ///
  /// - 默认书（`isDefault==true`）禁删（Repository 抛错 + 安全规则拦截）。
  /// - 删非空书：把其下所有 story 的 `storybookId` 迁回该用户默认书、
  ///   `chapterName` 置 `未分章`（**迁移而非级联删**，避免误删正文），
  ///   再删书文档。一次 [WriteBatch] 完成。
  Future<void> delete(String storybookId) async {
    final book = await getById(storybookId);
    if (book == null) return;
    if (book.isDefault) {
      throw StateError('默认故事书不可删除');
    }

    // 确保默认书存在，作为迁移落点。
    final defaultBook = await getOrCreateDefault(book.ownerId);

    // 必须带 authorId 过滤：stories 读规则要求查询能静态证明命中
    // authorId == uid，否则整条 list query 会被安全规则拒绝
    // （permission-denied）。删除书的人即 owner，其 uid == book.ownerId。
    final owned = await _stories
        .where('authorId', isEqualTo: book.ownerId)
        .where('storybookId', isEqualTo: storybookId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in owned.docs) {
      batch.update(doc.reference, {
        'storybookId': defaultBook.id,
        'chapterName': kDefaultChapter,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.delete(_col.doc(storybookId));
    // 迁入会改动默认书内容，顺手刷新它的 updatedAt。
    batch.update(_col.doc(defaultBook.id), {
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
