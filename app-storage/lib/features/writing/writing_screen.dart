import 'package:flutter/material.dart';

/// P2 写作模块占位。
/// 包括官方挑战入口、自由创作随机词入口、编辑器。
class WritingScreen extends StatelessWidget {
  const WritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('写作')),
      body: const Center(child: Text('写作 (P2)')),
    );
  }
}
