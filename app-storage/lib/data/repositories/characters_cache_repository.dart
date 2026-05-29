import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/character_cache.dart';

/// `charactersCache` 集合的读入口；写入由模块 G 负责，客户端只读（T1.4 规则）。
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
}
