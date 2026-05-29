import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/origami.dart';

/// `origami` 集合的读入口。客户端永远只读（T1.4 规则）；
/// 写入由 T1.8 的 Cloud Function `generateOrigami` 负责。
class OrigamiRepository {
  OrigamiRepository._();
  static final OrigamiRepository instance = OrigamiRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('origami');

  Future<Origami?> getById(String origamiId) async {
    final snap = await _col.doc(origamiId).get();
    if (!snap.exists) return null;
    return Origami.fromFirestore(snap);
  }

  Stream<Origami?> watchById(String origamiId) {
    return _col.doc(origamiId).snapshots().map(
          (snap) => snap.exists ? Origami.fromFirestore(snap) : null,
        );
  }

  /// 某用户的折纸藏品列表，按生成时间倒序。
  Stream<List<Origami>> streamMine(String ownerId, {int limit = 50}) {
    return _col
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) =>
            qs.docs.map(Origami.fromFirestore).toList(growable: false));
  }
}
