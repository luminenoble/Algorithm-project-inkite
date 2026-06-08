import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/character_cache.dart';

/// `charactersCache` 集合的读入口；写入由「开拓」栏离线导入脚本负责，
/// 客户端只读（T1.4 规则）。
class CharactersCacheRepository {
  CharactersCacheRepository._();
  static final CharactersCacheRepository instance =
      CharactersCacheRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('charactersCache');

  Future<CharacterCache?> getByKey(String characterKey) async {
    final snap = await _col.doc(characterKey).get();
    if (!snap.exists) return null;
    return CharacterCache.fromFirestore(snap);
  }

  Stream<CharacterCache?> watchByKey(String characterKey) {
    return _col.doc(characterKey).snapshots().map(
          (snap) => snap.exists ? CharacterCache.fromFirestore(snap) : null,
        );
  }

  /// 按角色名前缀搜索（app 端无全文索引，靠 `searchTokens` 数组匹配）。
  ///
  /// 导入脚本把角色名小写后生成累进前缀写进 `searchTokens`，这里用单字段
  /// `array-contains` 命中——无需复合索引（design.md §7 / 角色查询-todo §4.2）。
  Future<List<CharacterCache>> searchByName(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Future.value(const []);
    return _col
        .where('searchTokens', arrayContains: q)
        .limit(limit)
        .get()
        .then((s) => s.docs.map(CharacterCache.fromFirestore).toList());
  }

  /// 「开拓」落地页默认列表：按 `popularity` 降序取热门角色。
  /// 单字段排序不需复合索引。
  Future<List<CharacterCache>> listPopular({int limit = 30}) {
    return _col
        .orderBy('popularity', descending: true)
        .limit(limit)
        .get()
        .then((s) => s.docs.map(CharacterCache.fromFirestore).toList());
  }
}
