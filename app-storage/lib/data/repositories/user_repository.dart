import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// `users/{uid}` 读 / 监听 / 局部更新的统一入口。
///
/// 写入"初始档案"由 `AuthService._ensureProfile` 负责，本仓库不暴露 create——
/// 调用方拿到的语义只有"档案已存在，读它 / 改它的可写字段"。
class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromFirestore(snap);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map(
      (snap) => snap.exists ? UserProfile.fromFirestore(snap) : null,
    );
  }

  /// 仅更新昵称。预留给后续"我的→编辑昵称"页面。
  /// 用 `update` 而非 `set`，确保 T1.10 规则收紧后字段级写入仍可通过。
  Future<void> updateDisplayName(String uid, String displayName) {
    return _users.doc(uid).update({'displayName': displayName});
  }
}
