import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/brush_loading.dart';

/// T1.5 登录/注册页。
///
/// 三个入口：
///   - 登录（邮箱 + 密码）
///   - 注册（邮箱 + 密码 + 可选昵称），成功即自动登录
///   - 匿名试玩
///
/// 成功后路由守卫自动跳转 `/writing`，本页不主动 `context.go`。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _Mode.signIn) {
        await AuthService.instance.signInWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
      } else {
        await AuthService.instance.signUp(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _displayNameCtrl.text,
        );
      }
      // 登录/注册成功后路由守卫会自动跳走，无需 context.go
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _translateAuthError(e));
    } on TimeoutException {
      setState(() => _error = '网络超时，请检查连接后重试');
    } catch (e) {
      setState(() => _error = '失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _translateAuthError(e));
    } on TimeoutException {
      setState(() => _error = '网络超时，请检查连接后重试');
    } catch (e) {
      setState(() => _error = '失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _translateAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '该邮箱尚未注册';
      case 'wrong-password':
      case 'invalid-credential':
        return '邮箱或密码错误';
      case 'email-already-in-use':
        return '该邮箱已被注册';
      case 'weak-password':
        return '密码过弱，至少 6 位';
      case 'invalid-email':
        return '邮箱格式不正确';
      case 'network-request-failed':
        return '网络异常，请稍后再试';
      default:
        return '登录失败：${e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;
    return Scaffold(
      appBar: AppBar(title: const Text('Inkite — 登录')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_Mode>(
                    segments: const [
                      ButtonSegment(value: _Mode.signIn, label: Text('登录')),
                      ButtonSegment(value: _Mode.signUp, label: Text('注册')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() {
                              _mode = s.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return '请输入邮箱';
                      if (!s.contains('@')) return '邮箱格式不正确';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) {
                      final s = v ?? '';
                      if (s.isEmpty) return '请输入密码';
                      if (s.length < 6) return '密码至少 6 位';
                      return null;
                    },
                  ),
                  if (isSignUp) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '昵称（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(isSignUp ? '注册并登录' : '登录'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _signInAnonymously,
                    child: const Text('匿名试玩'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const Center(child: BrushLoading()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}