import 'package:flutter/material.dart';

/// P3 通道广场占位。
/// 故事动态、点赞评论、排行榜入口。
class SquareScreen extends StatelessWidget {
  const SquareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('广场')),
      body: const Center(child: Text('广场 (P3)')),
    );
  }
}
