import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

/// 登录页占位 UI。
///
/// 当前能力：匿名登录 + 一次 Firestore 写读验证（T1.3 端到端连通性检查）。
/// 真实的邮箱/密码登录由 T1.5 实现。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _status = '';
  bool _busy = false;

  Future<void> _signInAndProbe() async {
    setState(() {
      _busy = true;
      _status = '匿名登录中...';
    });
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user!.uid;

      setState(() => _status = '写入测试文档...');
      final docRef = FirebaseFirestore.instance.collection('_probe').doc(uid);
      await docRef.set({
        'uid': uid,
        'at': FieldValue.serverTimestamp(),
        'note': 'T1.3 hello-app probe',
      });

      setState(() => _status = '读回测试文档...');
      final snap = await docRef.get();
      assert(snap.exists);

      setState(() => _status = '端到端链路 OK，进入主框架');
      if (!mounted) return;
      context.go('/writing');
    } catch (e) {
      setState(() => _status = '失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inkite — 登录')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '当前为 T1.3 占位登录。\n'
                '点击下方按钮匿名登录并验证 Firebase 连通性。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _signInAndProbe,
                child: const Text('匿名登录并验证'),
              ),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
