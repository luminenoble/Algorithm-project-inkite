import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// 我的 Tab 占位。
/// 展示当前用户信息、登出按钮、角色查询（模块 G 嵌入位置由 P4 决定）。
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('uid: ${user?.uid ?? "未登录"}'),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('登出'),
            ),
          ],
        ),
      ),
    );
  }
}
