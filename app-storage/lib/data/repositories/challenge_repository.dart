import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/challenge.dart';

/// `challenges` 集合的读入口。客户端永远只读（T1.4 规则）。
class ChallengeRepository {
  ChallengeRepository._();
  static final ChallengeRepository instance = ChallengeRepository._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('challenges');

  /// 当前活跃挑战；约定全集合内 `isActive=true` 至多 1 条。
  Stream<Challenge?> watchActive() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('startAt', descending: true)
        .limit(1)
        .snapshots()
        .map((qs) =>
            qs.docs.isEmpty ? null : Challenge.fromFirestore(qs.docs.first));
  }

  Future<Challenge?> getById(String challengeId) async {
    final snap = await _col.doc(challengeId).get();
    if (!snap.exists) return null;
    return Challenge.fromFirestore(snap);
  }

  Future<List<Challenge>> listRecent({int limit = 10}) async {
    final qs = await _col
        .orderBy('startAt', descending: true)
        .limit(limit)
        .get();
    return qs.docs.map(Challenge.fromFirestore).toList(growable: false);
  }
}
