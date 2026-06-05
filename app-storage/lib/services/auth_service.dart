import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/user_profile.dart';

/// Firebase Auth 的薄封装 + 首次登录写 `users/{uid}` 初始档案。
///
/// 公共 API 见 `docs/P1/stage1/T1.5.md §「接口契约」`。
/// 所有 `signXxx` / `signUp` 都会在底层 Auth 调用成功后同步等待
/// `_ensureProfile(uid)` 完成才返回，调用方拿到的 [UserCredential]
/// 必然对应一条已存在的 users 文档。
class AuthService {
  AuthService._(this._auth, this._firestore);

  static final AuthService instance = AuthService._(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ---------------------------------------------------------------
  // 当前态
  // ---------------------------------------------------------------

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------
  // 登录路径
  // ---------------------------------------------------------------

  // Firebase C++ SDK 12.x 在 Windows release 模式下偶发平台回调不返回，
  // 加超时使 Future 失败而非永久挂起，方便上层显示错误而非无限转圈。
  static const _kAuthTimeout = Duration(seconds: 15);
  static const _kFirestoreTimeout = Duration(seconds: 10);

  Future<UserCredential> signInAnonymously() async {
    final cred = await _auth
        .signInAnonymously()
        .timeout(_kAuthTimeout);
    await _ensureProfile(cred.user!, displayNameHint: null)
        .timeout(_kFirestoreTimeout);
    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth
        .signInWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(_kAuthTimeout);
    // 老用户首次在新设备登录也可能没档案（极端情况），兜底再确保一次。
    await _ensureProfile(cred.user!, displayNameHint: null)
        .timeout(_kFirestoreTimeout);
    return cred;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth
        .createUserWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(_kAuthTimeout);
    await _ensureProfile(cred.user!, displayNameHint: displayName)
        .timeout(_kFirestoreTimeout);
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  // ---------------------------------------------------------------
  // 内部：首次登录写档案
  // ---------------------------------------------------------------

  /// 不存在则 `set` 一份初始档案；已存在则什么也不做。
  /// 不用 `set(merge: true)` 兜底——避免回填覆盖 CF 维护的 `stats.*`。
  Future<void> _ensureProfile(
    User user, {
    required String? displayNameHint,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (snap.exists) return;

    final initialName = _resolveInitialDisplayName(
      user: user,
      hint: displayNameHint,
    );
    await docRef.set(UserProfile.initialDoc(displayName: initialName));
  }

  String _resolveInitialDisplayName({
    required User user,
    required String? hint,
  }) {
    if (hint != null && hint.trim().isNotEmpty) return hint.trim();
    if (user.isAnonymous) {
      final shortId = user.uid.length >= 6 ? user.uid.substring(0, 6) : user.uid;
      return 'Guest-$shortId';
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Inkite User';
  }
}
